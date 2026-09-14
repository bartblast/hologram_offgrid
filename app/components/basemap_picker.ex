defmodule Offgrid.Components.BasemapPicker do
  @moduledoc """
  The maps a trip can be drawn on, as a row of thumbnails to choose from.

  The maps come from a query, so adding one is a row in the seeds. The choice is not kept here:
  it comes down as `selected_id`, and each pick goes to the `on_pick` action on `target` as
  `%{id: basemap_id}`. The new trip form keeps it in page state, and `MapPicker` writes it to
  the trip.
  """

  use Hologram.Component

  import Offgrid.Classes

  alias Offgrid.Components.BasemapThumb
  alias Offgrid.Entities.Basemap
  alias Offgrid.Queries

  prop :basemaps, [Basemap], from_query: &basemaps_query/0
  prop :on_pick, :atom, required: true
  prop :selected_id, :string, default: nil
  prop :target, :string, required: true

  # Mounts inside `MapPicker` in a page that is already loaded, so it needs init/2.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div class="thumbs">
      {%for basemap <- @basemaps}
        <button
          class={classes(["thumb", on: basemap.id == @selected_id])}
          type="button"
          $click={action: @on_pick, target: @target, params: %{id: basemap.id}}
        >
          <BasemapThumb slug={basemap.slug} />
          <b>{basemap.name}</b>
        </button>
      {/for}
    </div>
    """
  end

  defp basemaps_query, do: Queries.basemaps()
end
