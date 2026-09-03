defmodule Offgrid.Components.Ink do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  @moduledoc """
  Every stroke drawn on this trip, by anybody.

  A sketch keeps its points as real coordinates, so this projects them the way the pins and
  the route are projected and for the same reason: the ink is where it was drawn whatever
  size the window is, and it moves with the map when the trip changes basemap.

  The stroke being drawn right now is not here - it is on the page, in screen space, because
  it is not a row yet. This layer is the ink that has become rows.
  """

  prop :sketches, [Sketch], from_query: &sketches_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, matching the other always-drawn layers on this map, which hold no state either.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <svg class="ink-saved" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      {%for sketch <- @sketches}
        <polyline
          points={percent_points(sketch, @trip)}
          stroke={sketch.color}
          fill="none"
          vector-effect="non-scaling-stroke"
        />
      {/for}
    </svg>
    """
  end

  # "lat,lng lat,lng ..." back into the hundredths the map is drawn in.
  defp percent_points(sketch, trip) do
    sketch.points
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", fn pair ->
      [lat, lng] = String.split(pair, ",")
      {x, y} = Geo.to_percent(String.to_float(lat), String.to_float(lng), trip.basemap)

      "#{x},#{y}"
    end)
  end

  defp sketches_query(trip_id) do
    Sketch
    |> filter(trip_id: trip_id)
    |> order_by([:created_at, :id])
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> include(:basemap)
    |> one()
  end
end
