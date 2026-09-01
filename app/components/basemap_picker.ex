defmodule Offgrid.Components.BasemapPicker do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Basemap

  @moduledoc """
  The maps a trip can be drawn on, as a row of thumbnails to choose from.

  The maps come from a query rather than a list in the markup, so adding a fourth is a row
  in the seeds and nothing else. Which one is chosen belongs to whoever is filling the form,
  not to this component - it is handed down as a prop and handed back as an action, so the
  same picker works for a trip being created and a trip being edited.
  """

  prop :basemaps, [Basemap], from_query: &basemaps_query/0
  prop :selected_id, :string, default: nil

  def init(_props, component), do: component

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
