defmodule Offgrid.Components.MapPicker do
  @moduledoc """
  The maps an existing trip can be drawn on, opened from the swatch in the panel header.

  Picking one is a plain write to the trip. It lands in the client's database first, so the
  terrain behind the panel, drawn from the same row, changes in the same frame.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Components.BasemapPicker
  alias Offgrid.Entities.Trip
  alias Offgrid.Queries

  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # Mounts in a page that is already loaded, and a component initialized on the client needs
  # init/2 even when it has nothing to set up.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <BasemapPicker cid="map_basemaps" on_pick={:pick} selected_id={basemap_id(@trip)} target={@cid} />
    """
  end

  def action(:pick, params, component) do
    :ok = DB.update(Trip, component.props.trip_id, %{basemap_id: params.id})

    component
  end

  # Nothing is marked while the trip is unreadable.
  defp basemap_id(nil), do: nil

  defp basemap_id(trip), do: trip.basemap_id

  defp trip_query(trip_id), do: Queries.trip(trip_id)
end
