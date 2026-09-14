defmodule Offgrid.Entities.Basemap do
  @moduledoc """
  One of the maps a trip can be drawn on. Its bounds in latitude and longitude are what
  `Offgrid.Geo` projects a stop's place against.

  Named `Basemap` rather than `Map` because `alias Offgrid.Entities.Map` would silently shadow
  Elixir's own `Map` in that file.

  Read by anyone and written by nobody: the rows are seed data, and nothing grants create,
  update or delete.
  """

  use Hologram.Entity

  attribute :max_lat, :float
  attribute :max_lng, :float
  attribute :min_lat, :float
  attribute :min_lng, :float
  attribute :name, :string
  attribute :slug, :string, unique: true

  allow :read
end
