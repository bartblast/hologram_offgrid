defmodule Offgrid.Components.TripCalendar do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip

  @moduledoc """
  The trip's days as a grid, with a dot per stop already on each one.

  Picking a day writes the open stop's date. Nothing is reordered by hand anywhere in
  this app - the list derives its order from the date and time, so moving a stop is a
  field edit like any other, and merges like one.

  The range is the whole trip, so a day outside it cannot be chosen at all - read off the trip
  rather than written here, which it was until trips had dates of their own to read.

  The dots are the stops of THIS trip. They were every stop the client could read, which was
  invisible while one trip owned the screen and wrong the moment two did - the same mistake the
  itinerary made, and the same fix.
  """

  prop :date, :date
  prop :stop_id, :string
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div class="cal">
      {%for day <- trip_days(@trip)}
        <button type="button" class={day_class(day, @date)} $click={:pick, date: day}>
          <span class="dw">{weekday(Date.day_of_week(day))}</span>
          <span class="nm">{day.day}</span>
          <span class="dt">
            {%for _stop <- stops_on(@stops, day)}
              <i></i>
            {/for}
          </span>
        </button>
      {/for}
    </div>
    """
  end

  def action(:pick, params, component) do
    :ok = DB.update(Stop, component.props.stop_id, %{date: params.date})

    component
  end

  defp day_class(day, day), do: "on"

  defp day_class(_day, _selected), do: nil

  defp stops_on(stops, day) do
    Enum.filter(stops, &(&1.date == day))
  end

  defp stops_query(trip_id) do
    filter(Stop, trip_id: trip_id)
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> one()
  end

  # No trip readable, no days to offer - the same nothing every other layer on this screen
  # shows for a trip that is not this person's.
  defp trip_days(nil), do: []

  defp trip_days(trip), do: Date.range(trip.starts_on, trip.ends_on)

  defp weekday(1), do: "Mon"
  defp weekday(2), do: "Tue"
  defp weekday(3), do: "Wed"
  defp weekday(4), do: "Thu"
  defp weekday(5), do: "Fri"
  defp weekday(6), do: "Sat"
  defp weekday(7), do: "Sun"
end
