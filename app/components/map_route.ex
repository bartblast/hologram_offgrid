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

  While a pin is being carried the line comes with it. The place under the pointer is the
  page's, handed down the same way the pins take it, and it is already in the hundredths this
  line is drawn in - so the line bends as the hand moves and no row is touched until the
  pointer lifts.
  """

  prop :drag, :map, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, because a Link from one trip to another mounts this on the client.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <svg class="lay" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
      <polyline class="rt" points={points(@stops, @trip, @drag)} fill="none" vector-effect="non-scaling-stroke" />
    </svg>
    """
  end

  # A stop with no place, or a place off this map, is not on the line - the same rule the pins
  # follow, so the line only ever joins pins that are drawn.
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
