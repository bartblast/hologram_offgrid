defmodule Offgrid.Components.MapRoute do
  @moduledoc """
  The line through the trip's stops, in the order the itinerary runs them.

  Drawn in a 100 by 100 box stretched over the map, the same percentages the pins use, with a
  non-scaling stroke so the stretch does not distort its width. It sorts the way `StopsList`
  does, so moving a stop to another day redraws the line. While a pin is dragged, the line
  follows the page's drag position.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  prop :drag, :map, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  def template do
    ~HOLO"""
    <svg class="lay" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      <polyline class="rt" points={points(@stops, @trip, @drag)} fill="none" vector-effect="non-scaling-stroke" />
    </svg>
    """
  end

  # The same rule the pins follow, so the line only joins pins that are drawn.
  defp placed?(_stop, nil), do: false

  defp placed?(stop, trip), do: Geo.placed?(stop, trip.basemap)

  defp points(stops, trip, drag) do
    stops
    |> Enum.filter(&placed?(&1, trip))
    |> Enum.map_join(" ", &point(&1, trip, drag))
  end

  # Under the pointer for the stop being carried, and off its row for every other. A drag that
  # has not moved yet still reads from the row.
  defp point(stop, trip, %{id: id, x: x, y: y}) when x != nil do
    if id == stop.id, do: "#{x},#{y}", else: point(stop, trip, nil)
  end

  defp point(stop, trip, _drag) do
    {x, y} = Geo.to_percent(stop.lat, stop.lng, trip.basemap)

    "#{x},#{y}"
  end

  defp stops_query(trip_id) do
    Stop
    |> filter(trip_id: trip_id)
    |> order_by([:date, :time, :created_at])
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> include(:basemap)
    |> one()
  end
end
