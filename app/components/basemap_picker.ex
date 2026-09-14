defmodule Offgrid.Components.BasemapPicker do
  @moduledoc """
  The maps a new trip can be drawn on, as a row of thumbnails to choose from.

  The maps come from a query, so adding one is a row in the seeds. The choice belongs to the
  new trip form: it comes down as a prop and goes back up as an action. An existing trip
  changes its map through `MapPicker`, which writes to the trip directly.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Basemap

  prop :basemaps, [Basemap], from_query: &basemaps_query/0
  prop :selected_id, :string, default: nil

  def template do
    ~HOLO"""
    <div class="thumbs">
      {%for basemap <- @basemaps}
        <button
          class={thumb_class(basemap.id, @selected_id)}
          type="button"
          $click={action: :pick_basemap, target: "page", params: %{id: basemap.id}}
        >
          <BasemapThumb slug={basemap.slug} />
          <b>{basemap.name}</b>
        </button>
      {/for}
    </div>
    """
  end

  # Alphabetical by name, so the row is stable however the rows were seeded.
  defp basemaps_query do
    order_by(Basemap, :name)
  end

  defp thumb_class(id, id), do: "thumb on"

  defp thumb_class(_id, _selected_id), do: "thumb"
end
