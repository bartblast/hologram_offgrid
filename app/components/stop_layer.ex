defmodule Offgrid.Components.StopLayer do
  @moduledoc """
  The trip's stops on the map: the route through them in itinerary order, and a pin for each.

  Positions are computed from each stop's latitude and longitude, so they follow a change of
  basemap and a resized window. A stop with no coordinates yet, or a place off this map, has no
  pin and is not on the route.

  A pin can be dragged. While it is, the pin and the route follow the pointer, and the row is
  written once, when the pointer lifts. The pointer is followed on the document, because a drag
  outlives the pin it began on.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Device
  alias Offgrid.Entities.Basemap
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Queries
  alias Offgrid.Utils.CSS

  prop :open_stop_id, :string, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  def init(_props, component, _server), do: put_state(component, :drag, nil)

  def template do
    ~HOLO"""
    <svg class="lay" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      <polyline class="rt" points={route(@stops, @trip, @drag)} fill="none" vector-effect="non-scaling-stroke" />
    </svg>

    {%for stop <- placed(@stops, @trip)}
      <div
        class={CSS.class(["pin", mine: stop.id == @open_stop_id])}
        style={pin_style(stop, @trip, @drag)}
        $click={action: :open_stop, target: "page", params: %{id: stop.id}}
        $pointer_down={:drag_start, id: stop.id}
      >
        <i></i><em>{stop.name}</em>
      </div>
    {/for}

    {%if @drag}
      <document $pointer_move="drag_move" $pointer_up="drag_finish" />
    {/if}
    """
  end

  # A press that never moved writes nothing. It is a click, and the pin's own binding opens the
  # stop, as it also does when a drag ends over the pin.
  def action(:drag_finish, _params, component) do
    drop(component, component.state.drag, component.props.trip)
  end

  # In hundredths of the map, which is what the pin's style takes, whatever the map's size.
  def action(:drag_move, params, component) do
    drag = component.state.drag
    {left, top, width, height} = drag.rect
    event = params.event

    put_state(component, :drag, %{
      drag
      | x: (event.client_x - left) / width * 100,
        y: (event.client_y - top) / height * 100
    })
  end

  # The canvas is measured once, when a pin is pressed, and held for the drag.
  def action(:drag_start, params, component) do
    put_state(component, :drag, %{id: params.id, rect: Device.rect("canvas"), x: nil, y: nil})
  end

  defp drop(component, %{x: nil}, _trip), do: put_state(component, :drag, nil)

  defp drop(component, _drag, nil), do: put_state(component, :drag, nil)

  # The hundredths are offsets in a box a hundred wide, so the projection needs no other size.
  defp drop(component, drag, trip) do
    {lat, lng} = Basemap.from_offset(trip.basemap, drag.x, drag.y, 100, 100)

    DB.update!(Stop, drag.id, %{lat: lat, lng: lng})

    put_state(component, :drag, nil)
  end

  defp pin_style(stop, trip, drag) do
    {x, y} = position(stop, trip, drag)

    "left:#{x}%;top:#{y}%"
  end

  defp placed(_stops, nil), do: []

  defp placed(stops, trip), do: Enum.filter(stops, &Basemap.placed?(trip.basemap, &1))

  # Under the pointer for the stop being dragged, once it has moved, and where its row says
  # otherwise.
  defp position(%{id: id}, _trip, %{id: id, x: x, y: y}) when x != nil, do: {x, y}

  defp position(stop, trip, _drag), do: Basemap.to_percent(trip.basemap, stop.lat, stop.lng)

  defp route(stops, trip, drag) do
    stops
    |> placed(trip)
    |> Enum.map_join(" ", fn stop ->
      {x, y} = position(stop, trip, drag)

      "#{x},#{y}"
    end)
  end

  defp stops_query(trip_id), do: Queries.itinerary(trip_id)

  defp trip_query(trip_id), do: Queries.trip_with_basemap(trip_id)
end
