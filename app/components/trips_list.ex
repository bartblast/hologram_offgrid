defmodule Offgrid.Components.TripsList do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.UI.Link
  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Dates
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.TripPage

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
        <Link class="triprow" to={TripPage, id: trip.id}>
          <BasemapThumb slug={trip.basemap.slug} />

          <div>
            <b>{trip.name}</b>
            <span>{Dates.span(trip.starts_on, trip.ends_on)}</span>
          </div>
        </Link>
      {/for}
    </div>
    """
  end

  defp trips_query do
    Trip
    |> include(:basemap)
    |> order_by([{:created_at, :desc}])
  end
end
