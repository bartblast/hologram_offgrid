defmodule Offgrid.Components.InkTools do
  @moduledoc """
  Drawing on the map: the layer a stroke is drawn on, the saved ink, the pen and its colours.

  The stroke being drawn stays here in hundredths of the map, so a move is one division, and
  becomes a `Sketch` row when the pointer lifts. Whether the pen is out is the page's mode,
  because arming the pen disarms placing a stop.
  """

  use Hologram.Component
  use Hologram.DB

  import Offgrid.Classes

  alias Offgrid.Components.Ink
  alias Offgrid.Device
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo
  alias Offgrid.Queries
  alias Offgrid.Stroke

  # The theme's own five: the three the people on a trip are drawn in, the accent, and ink.
  @ink_colors ["#ff2d55", "#af52de", "#30b0c7", "#007aff", "#1d1d1f"]

  prop :drawing, :boolean
  prop :panel_open, :boolean
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string
  prop :user_id, :string

  def init(_props, component, _server) do
    put_state(component, box: nil, ink_color: hd(@ink_colors), stroke: [])
  end

  def template do
    ~HOLO"""
    <div
      class={classes(["ink", on: @drawing])}
      style={nib_cursor(@drawing, @ink_color)}
      $pointer_down="ink_start"
      $pointer_move="ink_extend"
      $pointer_up="ink_finish"
    ></div>

    <Ink cid="ink" drawing={@drawing} trip_id={@trip_id} user_id={@user_id} />

    <svg class="ink-paper" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      {%if @drawing && @stroke != []}
        <path
          d={stroke_path(@stroke)}
          stroke={@ink_color}
          fill="none"
          vector-effect="non-scaling-stroke"
        />
      {/if}
    </svg>

    <button
      class={classes(["pen", on: @drawing, flush: !@panel_open])}
      style={pen_style(@drawing, @ink_color)}
      type="button"
      aria-label="Draw"
      $click={action: :toggle_drawing, target: "page"}
    >
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4.5 19.5 L7.5 12 L15.5 4 L20 8.5 L12 16.5 Z" />
        <path class="solid" d="M4.5 19.5 L8.6 18 L6 15.4 Z" />
      </svg>
    </button>

    {%if @drawing}
      <div class={classes(["cpop", flush: !@panel_open])}>
        {%for color <- ink_colors()}
          <button
            class={classes(["cdot", on: color == @ink_color])}
            type="button"
            style={"background:#{color}"}
            aria-label={color}
            $click={:pick_color, color: color}
          ></button>
        {/for}
      </div>
    {/if}
    """
  end

  def action(:ink_extend, params, component) do
    case component.state.stroke do
      [] ->
        component

      stroke ->
        point = ink_point(component.state.box, params.event)

        put_state(component, :stroke, extend(stroke, point))
    end
  end

  # Lifting the pointer saves the stroke and drops the local copy, since the saved layer draws
  # it from then on. A stroke of one point is a tap, not a line, and is not saved.
  def action(:ink_finish, _params, component) do
    finish(component, Enum.reverse(component.state.stroke))
  end

  # The canvas is measured once, when the pointer goes down, and held for the stroke. Whether
  # the pen is armed is checked here rather than left to the layer's `pointer-events`, which
  # only decides what the pointer hits.
  def action(:ink_start, params, component) do
    if component.props.drawing do
      box = Device.rect("canvas")

      put_state(component, box: box, stroke: [ink_point(box, params.event)])
    else
      component
    end
  end

  def action(:pick_color, params, component) do
    put_state(component, :ink_color, params.color)
  end

  # Skips a point within half a percent of the last one, since every kept point costs time on
  # every render. Manhattan distance, because this runs on every pointer event.
  defp extend([{last_x, last_y} | _rest] = stroke, {x, y} = point) do
    if abs(x - last_x) + abs(y - last_y) < 0.5, do: stroke, else: [point | stroke]
  end

  defp finish(component, [_single_point]), do: put_state(component, :stroke, [])

  defp finish(component, []), do: component

  # No readable trip, as for a stranger, so the stroke is dropped the way a tap is.
  defp finish(%{props: %{trip: nil}} = component, _points) do
    put_state(component, :stroke, [])
  end

  defp finish(component, points) do
    {:ok, _sketch} =
      %{
        author_id: component.props.user_id,
        color: component.state.ink_color,
        path: sketch_path(points, component.props.trip),
        trip_id: component.props.trip_id
      }
      |> Sketch.new()
      |> DB.create()

    put_state(component, :stroke, [])
  end

  defp ink_colors, do: @ink_colors

  defp ink_point({_left, _top, width, height}, event) do
    {event.offset_x / width * 100, event.offset_y / height * 100}
  end

  # A pen nib in the loaded ink. The hotspot (`3 23`) sits on the nib's point rather than the
  # image's corner, so the line starts where it was aimed.
  #
  # The colour's `#` is percent-encoded, since a raw `#` in a data URI starts a fragment and
  # cuts the SVG short.
  defp nib_cursor(false, _ink_color), do: nil

  defp nib_cursor(true, "#" <> rgb) do
    svg =
      "<svg xmlns='http://www.w3.org/2000/svg' width='26' height='26'>" <>
        "<path d='M3 23 L6.5 14.5 L17.5 3.5 L22.5 8.5 L11.5 19.5 Z' fill='%23#{rgb}'" <>
        " stroke='white' stroke-width='1.6' stroke-linejoin='round'/>" <>
        "<path d='M3 23 L7.5 21 L5 18.5 Z' fill='white'/></svg>"

    "cursor: url(\"data:image/svg+xml;utf8,#{svg}\") 3 23, cell"
  end

  # The armed pen takes the loaded ink. The ring, not the colour, says it is armed, because
  # black is one of the inks and the resting button is already black.
  defp pen_style(false, _ink_color), do: nil

  defp pen_style(true, ink_color), do: "background:#{ink_color}"

  # The SVG path a sketch is stored as, in map coordinates: longitude across, latitude negated
  # to run down. The percentages are offsets in a box a hundred wide, so no other size is needed.
  defp sketch_path(points, trip) do
    points
    |> Enum.map(fn {x, y} ->
      {lat, lng} = Geo.from_offset(x, y, 100, 100, trip.basemap)

      {lng, -lat}
    end)
    |> Stroke.path()
  end

  # The points are held newest first, because a stroke grows by prepending.
  defp stroke_path(stroke) do
    stroke
    |> Enum.reverse()
    |> Stroke.path()
  end

  defp trip_query(trip_id), do: Queries.trip_with_basemap(trip_id)
end
