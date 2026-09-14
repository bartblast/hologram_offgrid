defmodule Offgrid.Geo do
  @moduledoc """
  The arithmetic between a place on Earth and a place on the screen.

  A basemap is a rectangle of latitude and longitude, and the projection between it and the
  screen is linear in both directions. Real cartography would use a Mercator curve vertically,
  which matters over a continent but not over one country. Latitude grows northward while
  screen offsets grow downward, so the top of the map is `max_lat` and the vertical arithmetic
  subtracts.
  """

  alias Offgrid.Entities.Basemap

  @doc """
  Returns true when the place falls inside the basemap's bounds, edges included.
  """
  @spec within?(number, number, Basemap.t()) :: boolean
  def within?(lat, lng, basemap) do
    lat >= basemap.min_lat and lat <= basemap.max_lat and
      lng >= basemap.min_lng and lng <= basemap.max_lng
  end

  @doc """
  Returns the `viewBox` that makes a drawing's coordinates the basemap's own.

  x is longitude and y is NEGATIVE latitude, because latitude grows northward while a drawing
  grows downward. A path stored in those units needs no projection: the browser draws it in
  place at whatever size the map is. With no basemap to read, the answer is the unit box.
  """
  @spec view_box(Basemap.t() | nil) :: String.t()
  def view_box(nil), do: "0 0 100 100"

  def view_box(basemap) do
    "#{basemap.min_lng} #{-basemap.max_lat} " <>
      "#{basemap.max_lng - basemap.min_lng} #{basemap.max_lat - basemap.min_lat}"
  end

  @doc """
  Returns true when the stop has a place, and that place is on the basemap.

  The one rule the pins and the route both follow: a stop with no coordinates yet is not drawn,
  and neither is one off the edge of the trip's map. Neither is an error.
  """
  @spec placed?(map, Basemap.t()) :: boolean
  def placed?(stop, basemap) do
    stop.lat != nil and stop.lng != nil and within?(stop.lat, stop.lng, basemap)
  end

  @doc """
  Returns where the place sits on the basemap, as percentages of its width and height from the
  top left.

  Percentages because that is what a pin's `style` wants, and they hold at any size the map is
  drawn at. A place outside the bounds gets a percentage outside 0 to 100 rather than an error.
  """
  @spec to_percent(number, number, Basemap.t()) :: {float, float}
  def to_percent(lat, lng, basemap) do
    x = (lng - basemap.min_lng) / (basemap.max_lng - basemap.min_lng) * 100
    y = (basemap.max_lat - lat) / (basemap.max_lat - basemap.min_lat) * 100

    {x, y}
  end

  @doc """
  Returns the place a point in the drawn map stands for, given where the point falls inside a
  box of the given size.

  The offsets are measured from the box's top left, as a click event carries them, and the size
  is the box as the browser last measured it.
  """
  @spec from_offset(number, number, number, number, Basemap.t()) :: {float, float}
  def from_offset(offset_x, offset_y, width, height, basemap) do
    lng = basemap.min_lng + offset_x / width * (basemap.max_lng - basemap.min_lng)
    lat = basemap.max_lat - offset_y / height * (basemap.max_lat - basemap.min_lat)

    {lat, lng}
  end
end
