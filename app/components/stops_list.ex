defmodule Offgrid.Components.StopsList do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop

  @moduledoc """
  The itinerary: every stop of the trip, under the day it happens on.

  The stops arrive as a registered query the client evaluates against its own database,
  so a stop written by an action shows up here in the same frame - before anything has
  been sent anywhere.

  Order is derived, never stored: day, then time, then when the row was created. A stop
  with no time sinks to the end of its day, which both tiers agree on - Postgres sorts
  nulls last ascending, and so does the client's query kernel.
  """

  prop :stops, [Stop], from_query: &stops_query/0

  def template do
    ~HOLO"""
    {%for day <- days(@stops)}
      <div class="day">{day_label(day)}</div>

      {%for stop <- day}
        <div class="stop">
          <h4>{stop.name}</h4>
          <p>{summary(stop)}</p>
        </div>
      {/for}
    {/for}
    """
  end

  # Consecutive runs of stops sharing a date. The query already ordered them, so chunking
  # preserves that order and never re-sorts.
  defp days(stops) do
    Enum.chunk_by(stops, & &1.date)
  end

  defp day_label([stop | _rest]) do
    date = stop.date

    "#{weekday(Date.day_of_week(date))} #{date.day} #{month(date.month)}"
  end

  defp month(1), do: "Jan"
  defp month(2), do: "Feb"
  defp month(3), do: "Mar"
  defp month(4), do: "Apr"
  defp month(5), do: "May"
  defp month(6), do: "Jun"
  defp month(7), do: "Jul"
  defp month(8), do: "Aug"
  defp month(9), do: "Sep"
  defp month(10), do: "Oct"
  defp month(11), do: "Nov"
  defp month(12), do: "Dec"

  defp stops_query do
    order_by(Stop, [:date, :time, :created_at])
  end

  # The second line of a row: the time when there is one, then whatever the stop says
  # about itself.
  defp summary(%Stop{description: nil, time: nil}), do: ""

  defp summary(%Stop{description: description, time: nil}), do: description

  defp summary(%Stop{description: nil, time: time}), do: time_label(time)

  defp summary(%Stop{description: description, time: time}) do
    "#{time_label(time)} · #{description}"
  end

  defp time_label(time) do
    "#{pad(time.hour)}:#{pad(time.minute)}"
  end

  defp pad(number) when number < 10, do: "0#{number}"

  defp pad(number), do: "#{number}"

  defp weekday(1), do: "Mon"
  defp weekday(2), do: "Tue"
  defp weekday(3), do: "Wed"
  defp weekday(4), do: "Thu"
  defp weekday(5), do: "Fri"
  defp weekday(6), do: "Sat"
  defp weekday(7), do: "Sun"
end
