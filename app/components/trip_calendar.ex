defmodule Offgrid.Components.TripCalendar do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop

  @moduledoc """
  The trip's days as a grid, with a dot per stop already on each one.

  Picking a day writes the open stop's date. Nothing is reordered by hand anywhere in
  this app - the list derives its order from the date and time, so moving a stop is a
  field edit like any other, and merges like one.

  The range is the whole trip, so a day outside it cannot be chosen at all.
  """

  prop :date, :date
  prop :stop_id, :string
  prop :stops, [Stop], from_query: &stops_query/0

  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div class="cal">
      {%for day <- trip_days()}
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

  defp stops_query do
    Stop
  end

  # TODO: read the range off the trip once trips exist (phase E).
  defp trip_days do
    Date.range(~D[2026-03-28], ~D[2026-04-06])
  end

  defp weekday(1), do: "Mon"
  defp weekday(2), do: "Tue"
  defp weekday(3), do: "Wed"
  defp weekday(4), do: "Thu"
  defp weekday(5), do: "Fri"
  defp weekday(6), do: "Sat"
  defp weekday(7), do: "Sun"
end
