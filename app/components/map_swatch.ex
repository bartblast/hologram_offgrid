defmodule Offgrid.Components.MapSwatch do
  @moduledoc """
  The button in the itinerary panel's header that opens the map picker, showing the trip's map
  in miniature. Empty for a trip this person may not read.
  """

  use Hologram.Component

  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Trip
  alias Offgrid.Queries

  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  def template do
    ~HOLO"""
    <button
      class="swatch"
      type="button"
      aria-label="Change map"
      $click={action: :toggle_maps, target: "page"}
    >
      {%if @trip}
        <BasemapThumb slug={@trip.basemap.slug} />
      {/if}
    </button>
    """
  end

  defp trip_query(trip_id), do: Queries.trip_with_basemap(trip_id)
end
