defmodule Offgrid.Components.TripsList do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Trip

  @moduledoc """
  Every trip the person is on, newest first.

  The query is the whole authorization: it asks for trips and gets back the ones the
  session may read, which membership decides. Nothing here filters by user, and nothing
  here could - a client asking for more would be answered with the same rows.

  Newest first because the trip you just made is the one you want, and a trip's own dates
  say nothing about when you last cared about it.
  """

  prop :trips, [Trip], from_query: &trips_query/0

  def template do
    ~HOLO"""
    {%if @trips == []}
      <div class="blank">
        <b>No trips yet</b>
        <span>Start one and it shows up here, on every device you use.</span>
      </div>
    {/if}

    <div class="rowlist">
      {%for trip <- @trips}
        <!-- TODO: point at the trip's own address once the page has one. -->
        <a class="triprow" href="/">
          <BasemapThumb slug={trip.basemap.slug} />

          <div>
            <b>{trip.name}</b>
            <span>{days(trip)}</span>
          </div>
        </a>
      {/for}
    </div>
    """
  end

  # "28 Mar – 6 Apr", and "28 – 30 Mar" when one month covers it - repeating the month is
  # noise the reader has to look past.
  defp days(%Trip{ends_on: ends_on, starts_on: starts_on}) do
    if starts_on.month == ends_on.month do
      "#{starts_on.day} – #{ends_on.day} #{month(ends_on.month)}"
    else
      "#{starts_on.day} #{month(starts_on.month)} – #{ends_on.day} #{month(ends_on.month)}"
    end
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

  defp trips_query do
    Trip
    |> include(:basemap)
    |> order_by([{:created_at, :desc}])
  end
end
