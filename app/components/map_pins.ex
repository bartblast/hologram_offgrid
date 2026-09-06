defmodule Offgrid.Components.MapPins do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  @moduledoc """
  Every stop of the trip that has a place, drawn where that place falls on the map.

  A stop keeps its latitude and longitude and nothing else about where it is on screen, so
  the pins move when the trip changes map and follow the window when it resizes - the position
  is arithmetic on the row rather than a number stored beside it.

  Two kinds of stop are not drawn and neither is an error: one with no coordinates yet, which
  is every stop until somebody points at the map, and one whose place is off the edge of the
  map the trip is on.

  A pin can be picked up and put down somewhere else. While that is happening the page holds
  where the pointer is and this draws that pin there instead of where its row says - the row
  is only written when the pointer lifts, so a drag costs one write rather than one per frame.
  """

  prop :drag, :map, default: nil
  prop :open_stop_id, :string, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, because a Link from one trip to another mounts this on the client.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    {%for stop <- pinned(@stops, @trip)}
      <div
        class={pin_class(stop, @open_stop_id)}
        style={position(stop, @trip, @drag)}
        $click={action: :open_stop, target: "page", params: %{id: stop.id}}
        $pointer_down={action: :drag_start, target: "page", params: %{id: stop.id}}
      >
        <i></i><em>{stop.name}</em>
      </div>
    {/for}
    """
  end

  defp pin_class(stop, open_stop_id) do
    if stop.id == open_stop_id, do: "pin mine", else: "pin"
  end

  defp pinned(stops, trip) do
    Enum.filter(stops, &placed?(&1, trip))
  end

  defp placed?(_stop, nil), do: false

  defp placed?(stop, trip), do: Geo.placed?(stop, trip.basemap)

  # Under the pointer while this pin is the one being dragged, and where its row says
  # otherwise. A drag that has not moved yet still reads from the row.
  defp position(stop, trip, %{id: id, x: x, y: y}) when x != nil do
    if id == stop.id, do: "left:#{x}%;top:#{y}%", else: position(stop, trip, nil)
  end

  defp position(stop, trip, _drag) do
    {x, y} = Geo.to_percent(stop.lat, stop.lng, trip.basemap)

    "left:#{x}%;top:#{y}%"
  end

  defp stops_query(trip_id) do
    filter(Stop, trip_id: trip_id)
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> include(:basemap)
    |> one()
  end
end
