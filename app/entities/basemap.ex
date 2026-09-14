defmodule Offgrid.Entities.Basemap do
  @moduledoc """
  One of the maps a trip can be drawn on, and the arithmetic between a place on Earth and a
  place on it.

  A basemap is a rectangle of latitude and longitude, and the projection between it and the
  screen is linear in both directions. Real cartography would use a Mercator curve vertically,
  which matters over a continent but not over one country. Latitude grows northward while
  screen offsets grow downward, so the top of the map is `max_lat` and the vertical arithmetic
  subtracts.

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

  @doc """
  Returns the place a point in the drawn map stands for, given where the point falls inside a
  box of the given size.

  The offsets are measured from the box's top left, as a click event carries them, and the size
  is the box as the browser last measured it.
  """
  @spec from_offset(t, number, number, number, number) :: {float, float}
  def from_offset(basemap, offset_x, offset_y, width, height) do
    lng = basemap.min_lng + offset_x / width * (basemap.max_lng - basemap.min_lng)
    lat = basemap.max_lat - offset_y / height * (basemap.max_lat - basemap.min_lat)

    {lat, lng}
  end

  @doc """
  Returns true when the stop has a place, and that place is on the basemap.

  The one rule the pins and the route both follow: a stop with no coordinates yet is not drawn,
  and neither is one off the edge of the trip's map. Neither is an error.
  """
  @spec placed?(t, map) :: boolean
  def placed?(basemap, stop) do
    stop.lat != nil and stop.lng != nil and within?(basemap, stop.lat, stop.lng)
  end

  @doc """
  Returns where the place sits on the basemap, as percentages of its width and height from the
  top left.

  Percentages because that is what a pin's `style` wants, and they hold at any size the map is
  drawn at. A place outside the bounds gets a percentage outside 0 to 100 rather than an error.
  """
  @spec to_percent(t, number, number) :: {float, float}
  def to_percent(basemap, lat, lng) do
    x = (lng - basemap.min_lng) / (basemap.max_lng - basemap.min_lng) * 100
    y = (basemap.max_lat - lat) / (basemap.max_lat - basemap.min_lat) * 100

    {x, y}
  end

  @doc """
  Returns the `viewBox` that makes a drawing's coordinates the basemap's own.

  x is longitude and y is NEGATIVE latitude, because latitude grows northward while a drawing
  grows downward. A path stored in those units needs no projection: the browser draws it in
  place at whatever size the map is.
  """
  @spec view_box(t) :: String.t()
  def view_box(basemap) do
    "#{basemap.min_lng} #{-basemap.max_lat} " <>
      "#{basemap.max_lng - basemap.min_lng} #{basemap.max_lat - basemap.min_lat}"
  end

  @doc """
  Returns true when the place falls inside the basemap's bounds, edges included.
  """
  @spec within?(t, number, number) :: boolean
  def within?(basemap, lat, lng) do
    lat >= basemap.min_lat and lat <= basemap.max_lat and
      lng >= basemap.min_lng and lng <= basemap.max_lng
  end
end
