defmodule Offgrid.Components.Ink do
  @moduledoc """
  Every saved stroke on this trip, by anybody. The stroke being drawn is on the page until it
  becomes a row.

  A sketch is one SVG path in the map's own coordinates, longitude across and latitude down.
  The basemap's bounds go into the `viewBox`, so the layer projects nothing and the ink moves
  with the map. With the pen out, a line you may rub out takes the pointer and a click deletes
  it. The layer sits above the drawing surface, so a press anywhere else starts a new line.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  prop :drawing, :boolean
  prop :sketches, [Sketch], from_query: &sketches_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string
  prop :user_id, :string

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

  # Only with the pen out, and only a line this person may rub out. The server checks again
  # when the delete lands. A thin line is hard to hit, so a wider invisible path takes the click.
  defp erasable?(sketch, true, user_id), do: Auth.can?(user_id, :delete, sketch)

  defp erasable?(_sketch, false, _user_id), do: false

  # Nothing to draw until the trip is readable.
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
