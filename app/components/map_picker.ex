defmodule Offgrid.Components.MapPicker do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Basemap
  alias Offgrid.Entities.Trip

  @moduledoc """
  The maps a trip can be drawn on, opened from the swatch in the panel header.

  Every basemap is readable by everyone - they are the app's own scenery rather than anybody's
  data - so the row is the same three wherever you are. Which one is on comes from the trip.

  Picking one is a plain write to the trip, so it lands in the client's database first: the
  terrain behind the panel is drawn from the same row and changes in the same frame, with no
  network in between. That makes this the smallest complete demonstration of the claim - one
  click, one local write, the whole screen answering.
  """

  prop :basemaps, [Basemap], from_query: &basemaps_query/0
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, because the row appears in a page that is already loaded, the way every other
  # thing behind an {%if} on this screen does.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div class="thumbs">
      {%for basemap <- @basemaps}
        <button class={thumb_class(basemap, @trip)} type="button" $click={:pick, id: basemap.id}>
          <BasemapThumb slug={basemap.slug} />
          <b>{basemap.name}</b>
        </button>
      {/for}
    </div>
    """
  end

  def action(:pick, params, component) do
    :ok = DB.update(Trip, component.props.trip_id, %{basemap_id: params.id})

    component
  end

  defp basemaps_query, do: order_by(Basemap, :name)

  # Nothing is marked while the trip is unreadable, which is the same nothing the header and
  # the itinerary show for it.
  defp thumb_class(_basemap, nil), do: "thumb"

  defp thumb_class(basemap, trip) do
    if basemap.id == trip.basemap_id, do: "thumb on", else: "thumb"
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> one()
  end
end
