defmodule Offgrid.Components.Ink do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  @moduledoc """
  Every stroke drawn on this trip, by anybody.

  A sketch keeps its whole line as one SVG path, written in the map's own coordinates -
  longitude across and latitude down. So this layer projects nothing: the basemap's bounds go
  into the `viewBox` and the browser does the rest, which is why the ink is where it was drawn
  whatever size the window is and moves with the map when the trip changes basemap.

  That is what keeps this screen quick with ink on it. The path used to be rebuilt from stored
  coordinates on every render - split, two numbers parsed and projected per point, the path
  written out again - and a screen carrying a thousand points spent longer redrawing ink than
  doing everything else together. Now a stroke is one string handed to one attribute.

  The stroke being drawn right now is not here - it is on the page, in screen space, because
  it is not a row yet. This layer is the ink that has become rows.

  With the pen out, a line you may rub out takes the pointer and a click deletes it, which is
  why this layer sits above the one being drawn on: a press that lands on a line erases, and a
  press that lands anywhere else starts a new one. Lines you may not rub out never take the
  pointer at all, so the cursor tells you before you click.
  """

  prop :drawing, :boolean
  prop :sketches, [Sketch], from_query: &sketches_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string
  prop :user_id, :string

  # init/2, matching the other always-drawn layers on this map, which hold no state either.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <svg
      class="ink-saved"
      viewBox={view_box(@trip)}
      preserveAspectRatio="none"
      aria-hidden="true"
    >
      {%for sketch <- drawable(@sketches, @trip)}
        {%if erasable?(sketch, @drawing, @user_id)}
          <path
            class="ink-hit"
            d={sketch.points}
            fill="none"
            vector-effect="non-scaling-stroke"
            $click={:erase, id: sketch.id}
          />
        {/if}

        <path
          class="ink-line"
          d={sketch.points}
          stroke={sketch.color}
          fill="none"
          vector-effect="non-scaling-stroke"
        />
      {/for}
    </svg>
    """
  end

  def action(:erase, params, component) do
    :ok = DB.delete(Sketch, params.id)

    component
  end

  # Only with the pen out, and only a line this person may rub out - the browser answers that
  # from the rules it already holds, and the server asks it again when the delete lands.
  #
  # A line is three and a half pixels of ink and a poor thing to aim at, so what takes the
  # click is an invisible one drawn fat over the top of it.
  defp erasable?(sketch, true, user_id), do: Auth.can?(user_id, :delete, sketch)

  defp erasable?(_sketch, false, _user_id), do: false

  # Nothing to draw until the trip is readable - the same nothing the header and the itinerary
  # show for a trip that is not this person's, and the same nothing for the frame before the
  # client's database has it.
  defp drawable(_sketches, nil), do: []

  defp drawable(sketches, _trip), do: sketches

  defp sketches_query(trip_id) do
    Sketch
    |> filter(trip_id: trip_id)
    |> order_by([:created_at, :id])
  end

  # The trip's own bounds, so every path inside needs no arithmetic at all.
  defp view_box(nil), do: Geo.view_box(nil)

  defp view_box(trip), do: Geo.view_box(trip.basemap)

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> include(:basemap)
    |> one()
  end
end
