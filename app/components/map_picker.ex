defmodule Offgrid.Components.MapPicker do
  @moduledoc """
  The maps an existing trip can be drawn on, opened from the swatch in the panel header.

  Picking one is a plain write to the trip. It lands in the client's database first, so the
  terrain behind the panel, drawn from the same row, changes in the same frame.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Basemap
  alias Offgrid.Entities.Trip

  prop :basemaps, [Basemap], from_query: &basemaps_query/0
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # Mounts in a page that is already loaded, and a component initialized on the client needs
  # init/2 even when it has nothing to set up.
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

  # Nothing is marked while the trip is unreadable.
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
