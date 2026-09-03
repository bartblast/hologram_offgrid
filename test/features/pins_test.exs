defmodule Offgrid.Features.PinsTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Offgrid.Entities.Stop
  alias Wallaby.Element

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  # The map, the itinerary and the route all read the same rows, so this walks one stop
  # through its life and checks that all three keep agreeing without being told to.
  feature "a stop placed on the map lives on the map until it is deleted",
          %{session: session, trip: trip} do
    # Tokyo, on the second day, east of the middle of the map where the click will land.
    %{
      date: ~D[2026-03-29],
      lat: 35.6762,
      lng: 139.6503,
      name: "Shibuya crossing",
      trip_id: trip.id
    }
    |> Stop.new()
    |> DB.create!()

    session = sign_in_as_member(session, trip)

    session
    |> assert_has(css(".pin", count: 1))
    |> click(css(".addb"))
    |> click(css("#canvas"))
    # One click: a row on the itinerary, a pin on the map, and the editor open on it.
    |> assert_text(css(".stop.open"), "New stop")
    |> assert_has(css(".pin", count: 2))
    |> assert_has(css(".pin.mine", count: 1))

    # It landed on the first day, so it comes before Tokyo and the route runs west to east.
    [first, second] = route_xs(session)
    assert first < second

    # Move it to the third day and the route turns around - nothing redrew it but the row.
    click(session, css(".cal button", text: "30"))
    assert_text(session, css(".ed-sub"), "Mon 30 Mar")

    [first, second] = route_xs(session)
    assert first > second

    session
    |> click(button("Delete stop"))
    |> refute_has(css(".editor"))
    |> assert_has(css(".pin", count: 1))
    |> refute_has(css(".pin.mine"))

    assert [_only] = route_xs(session)
  end

  # The x of every point on the route, in the order the line runs them. Visibility is not
  # asked about, because a line through one point has no area and a browser calls that
  # invisible - and one point is precisely what the last assertion wants to see.
  defp route_xs(session) do
    session
    |> find(css(".lay polyline", visible: :any))
    |> Element.attr("points")
    |> String.split(" ", trim: true)
    |> Enum.map(fn pair ->
      [x, _y] = String.split(pair, ",")

      String.to_float(x)
    end)
  end
end
