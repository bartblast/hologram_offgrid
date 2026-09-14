defmodule Offgrid.Components.TripsList do
  @moduledoc """
  Every trip the person is on, newest first, because the trip you just made is usually the one
  you want.

  The query asks for all trips and gets back only those the session's memberships let it read,
  so nothing here filters by user.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.UI.Link
  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Dates
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.TripPage

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
