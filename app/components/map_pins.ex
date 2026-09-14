defmodule Offgrid.Components.MapPins do
  @moduledoc """
  Every stop of the trip that has a place on this map, drawn where that place falls.

  A pin's position is computed from the stop's latitude and longitude, so pins follow a change
  of basemap and a resized window. A stop with no coordinates yet, or a place off the map, is
  not drawn. While a pin is dragged the page holds the pointer position and the pin is drawn
  there. The row is written once, when the pointer lifts.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo

  prop :drag, :map, default: nil
  prop :open_stop_id, :string, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

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
