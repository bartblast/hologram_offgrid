defmodule Offgrid.Components.TripHeader do
  @moduledoc """
  The trip's name and dates, at the top of the itinerary panel. Clicking the name opens the
  trip details card.

  A component because a page cannot hold a query prop, and edits from the details card should
  show here without a reload. For a trip this person may not read, the header is empty.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Dates
  alias Offgrid.Entities.Trip

  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  def template do
    ~HOLO"""
    <div>
      {%if @trip}
        <button class="lp-title" type="button" $click={action: :open_details, target: "page"}>
          {@trip.name}
        </button>
        <div class="lp-dates">{Dates.span(@trip.starts_on, @trip.ends_on)}</div>
      {/if}
    </div>
    """
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> one()
  end
end
