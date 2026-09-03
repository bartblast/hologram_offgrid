defmodule Offgrid.Components.TripHeader do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Dates
  alias Offgrid.Entities.Trip

  @moduledoc """
  The trip's name and dates, at the top of the itinerary panel.

  A component rather than markup on the page, because a page cannot hold a query prop and this
  wants to be one: the name and the dates become editable in the trip details card, and an
  edit should show without a reload.

  The query answers nothing for a trip this person may not read - the trip's own rules decide
  that, not this component - so the header is empty rather than wrong.
  """

  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, because the header mounts on the client whenever a Link carries you from one trip
  # to another without a page load.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div>
      {%if @trip}
        <div class="lp-title">{@trip.name}</div>
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
