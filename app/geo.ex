defmodule Offgrid.Geo do
  @moduledoc """
  The arithmetic between a place on Earth and a place on the screen.

  A basemap is a rectangle of latitude and longitude drawn at some size, and the projection
  between the two is linear in both directions - a stand-in for the real thing, chosen because
  it can be read, tested and ported to the browser in one piece. Real cartography would put a
  Mercator curve in the vertical, which matters over a continent and not over one country.

  The vertical runs the other way from the horizontal, which is the only part worth watching:
  latitude grows northward and screen offsets grow downward, so the top of the map is
  `max_lat` and the arithmetic subtracts rather than adds.
  """

  alias Offgrid.Entities.Basemap

  @doc """
  Returns where the place sits on the basemap, as percentages of its width and height from the
  top left.

  Percentages because that is what a pin's `style` wants, and because they hold whatever size
  the map is drawn at. A place outside the basemap's bounds gets a percentage outside 0 to 100
  rather than an error - whether such a place is drawn at all is the map's question, not this
  one's.
  """
  @spec to_percent(float, float, Basemap.t()) :: {float, float}
  def to_percent(lat, lng, basemap) do
    x = (lng - basemap.min_lng) / (basemap.max_lng - basemap.min_lng) * 100
    y = (basemap.max_lat - lat) / (basemap.max_lat - basemap.min_lat) * 100

    {x, y}
  end

  @doc """
  Returns the place a point in the drawn map stands for, given where the point falls inside a
  box of the given size.

  The offsets are the ones a click event carries, measured from the box's top left, and the
  size is the box as the browser last measured it. Both are needed: percentages alone cannot
  say where a click landed, and the map is drawn at whatever size the window allows.
  """
  @spec from_offset(number, number, number, number, Basemap.t()) :: {float, float}
  def from_offset(offset_x, offset_y, width, height, basemap) do
    lng = basemap.min_lng + offset_x / width * (basemap.max_lng - basemap.min_lng)
    lat = basemap.max_lat - offset_y / height * (basemap.max_lat - basemap.min_lat)

    {lat, lng}
  end
end
