defmodule Offgrid.Components.TripCalendar do
  @moduledoc """
  The trip's days as a grid, with a dot for each of this trip's stops on that day.

  Picking a day writes the open stop's date. The itinerary derives its order from date and
  time, so moving a stop is a field edit like any other, and merges like one. Only days within
  the trip's dates are offered.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Dates
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip

  prop :date, :date
  prop :stop_id, :string
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # Mounts in a page that is already loaded, and a component initialized on the client needs
  # init/2 even when it has nothing to set up.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div class="cal">
      {%for day <- trip_days(@trip)}
        <button type="button" class={day_class(day, @date)} $click={:pick, date: day}>
          <span class="dw">{Dates.weekday(day)}</span>
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

  # No readable trip, no days to offer.
  defp trip_days(nil), do: []

  defp trip_days(trip), do: Date.range(trip.starts_on, trip.ends_on)
end
