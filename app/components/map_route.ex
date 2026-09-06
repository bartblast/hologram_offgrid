defmodule Offgrid.Components.MapRoute do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  @moduledoc """
  The line through the trip's stops, in the order the itinerary runs them.

  Drawn in percent space - a 100 by 100 box stretched over the map - so a point here and the
  pin at the same place are the same two numbers, and neither knows the map's size. The
  stroke is told not to scale, or the stretch would draw it thick one way and thin the other.

  It reads the same ordering the itinerary does, date then time then creation, so moving a
  stop to another day redraws the line without anything telling it to: two components reading
  one row set, agreeing because they cannot disagree.
  """

  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, because a Link from one trip to another mounts this on the client.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <svg class="lay" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      <polyline class="rt" points={points(@stops, @trip)} fill="none" vector-effect="non-scaling-stroke" />
    </svg>
    """
  end

  # A stop with no place, or a place off this map, is not on the line - the same rule the pins
  # follow, so the line only ever joins pins that are drawn.
  defp placed?(_stop, nil), do: false

  defp placed?(stop, trip), do: Geo.placed?(stop, trip.basemap)

  defp points(stops, trip) do
    stops
    |> Enum.filter(&placed?(&1, trip))
    |> Enum.map_join(" ", fn stop ->
      {x, y} = Geo.to_percent(stop.lat, stop.lng, trip.basemap)

      "#{x},#{y}"
    end)
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
