defmodule Offgrid.Entities.Basemap do
  use Hologram.Entity

  attribute :max_lat, :float
  attribute :max_lng, :float
  attribute :min_lat, :float
  attribute :min_lng, :float
  attribute :name, :string
  attribute :slug, :string, unique: true

  @moduledoc """
  One of the maps a trip can be drawn on - the layer under everything else, which is what
  "basemap" means wherever maps are made.

  The bounds are what turn a stop's real latitude and longitude into a position on screen,
  so a map is a projection the app can do arithmetic with rather than a picture with a name.
  A stop outside them has nowhere to be drawn, which is the rule the pins follow.

  Named `Basemap` rather than `Map` because an entity gets a `new/1`, and a bare
  `alias Offgrid.Entities.Map` would shadow Elixir's own `Map` in that file - silently, with
  no warning, so `Map.get/2` beside it would call the wrong module. The relationship a trip
  holds is still called `:map`, because that is the word the person using the app sees.

  Read by anyone, written by nobody: these three rows are seed data, and the app offers no
  way to add a fourth. Nothing grants create, update or delete, so no browser can write one.
  """

  allow :read
end
