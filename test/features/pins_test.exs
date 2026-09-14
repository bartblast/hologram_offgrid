defmodule Offgrid.Features.PinsTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Entities.Stop
  alias Wallaby.Element

  setup do
    reset_data()

    [trip: create_trip()]
  end

  feature "pins the stops that have a place, and only those",
          %{session: session, trip: trip} do
    # Kyoto, inside the Japan bounds.
    create_stop(trip, date: ~D[2026-03-28], lat: 35.0116, lng: 135.7681, name: "Fushimi Inari")

    # Warsaw, which is on another of the app's maps entirely.
    create_stop(trip, date: ~D[2026-03-29], lat: 52.23, lng: 21.01, name: "Old Town at dusk")

    # No place at all, which is every stop until somebody points at the map.
    create_stop(trip, date: ~D[2026-03-30], name: "Somewhere to decide")

    session
    |> sign_in(trip)
    # All three are on the itinerary. Only the one with a place on this map is on the map.
    |> assert_text(css(".lpanel"), "Somewhere to decide")
    |> assert_has(css(".pin", count: 1))
    |> assert_text(css(".pin"), "FUSHIMI INARI")
    # Clicking the pin opens the same editor the itinerary row opens.
    |> click(css(".pin"))
    |> assert_text(css(".editor"), "Fushimi Inari")
    |> assert_has(css(".pin.mine"))
  end

  feature "draws the route through the pins in itinerary order", %{session: session, trip: trip} do
    # Tokyo first in the database and second on the itinerary, so that the line following
    # creation order would run the wrong way.
    create_stop(trip, date: ~D[2026-03-29], lat: 35.6762, lng: 139.6503, name: "Shibuya crossing")

    create_stop(trip, date: ~D[2026-03-28], lat: 35.0116, lng: 135.7681, name: "Fushimi Inari")

    # Off this map, so not on the line either.
    create_stop(trip, date: ~D[2026-03-30], lat: 52.23, lng: 21.01, name: "Old Town at dusk")

    session = sign_in(session, trip)

    assert_has(session, css(".pin", count: 2))

    # Two points, Kyoto then Tokyo: the first x is the smaller one, because Kyoto is west.
    assert [{kyoto_x, _kyoto_y}, {tokyo_x, _tokyo_y}] = route_points(session)
    assert kyoto_x < tokyo_x
  end

  # The map, the itinerary and the route all read the same rows, so this walks one stop
  # through its life and checks that all three keep agreeing without being told to.
  feature "a stop placed on the map lives on the map until it is deleted",
          %{session: session, trip: trip} do
    # Tokyo, on the second day, east of the middle of the map where the click will land.
    create_stop(trip, date: ~D[2026-03-29], lat: 35.6762, lng: 139.6503, name: "Shibuya crossing")

    session = sign_in(session, trip)

    session
    |> assert_has(css(".pin", count: 1))
    |> click(css(".addb"))
    |> click(css("#canvas"))
    # One click: a row on the itinerary, a pin on the map, and the editor open on it.
    |> assert_text(css(".stop.open"), "New stop")
    |> assert_has(css(".pin", count: 2))
    |> assert_has(css(".pin.mine", count: 1))

    # It landed on the first day, so it comes before Tokyo and the route runs west to east.
    [{first, _first_y}, {second, _second_y}] = route_points(session)
    assert first < second

    # Move it to the third day and the route turns around - nothing redrew it but the row.
    click(session, css(".cal button", text: "30"))
    assert_text(session, css(".ed-sub"), "Mon 30 Mar")

    [{first, _first_y}, {second, _second_y}] = route_points(session)
    assert first > second

    session
    |> click(button("Delete stop"))
    |> refute_has(css(".editor"))
    |> assert_has(css(".pin", count: 1))
    |> refute_has(css(".pin.mine"))

    assert [_only] = route_points(session)
  end

  feature "a pin can be picked up and put down somewhere else",
          %{session: session, trip: trip} do
    # Kyoto, west of the middle of the Japan map.
    stop =
      create_stop(trip,
        date: ~D[2026-03-28],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari"
      )

    session =
      session
      |> sign_in(trip)
      |> assert_has(css(".pin", count: 1))

    [{before_x, _before_y}] = pin_positions(session)

    # Picked up and carried east, and let go there.
    session = drag_pin(session, {600, 300})

    # The pin is where it was let go, on screen and in the row - and further east than it was.
    [{after_x, _after_y}] = pin_positions(session)
    assert after_x > before_x

    await_pending_writes(session, 0)

    moved = Stop |> filter(id: stop.id) |> one() |> DB.read()
    assert moved.lng > stop.lng
    # It was carried, not re-created: the same row, with its name and day untouched.
    assert moved.name == "Fushimi Inari"
    assert moved.date == ~D[2026-03-28]
  end

  feature "a pin that is only clicked stays where it is", %{session: session, trip: trip} do
    stop =
      create_stop(trip,
        date: ~D[2026-03-28],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari"
      )

    session
    |> sign_in(trip)
    |> click(css(".pin"))
    # A press that never moved is a click: the editor opens and nothing is written.
    |> assert_text(css(".ed-title"), "Fushimi Inari")
    |> await_pending_writes(0)

    unmoved = Stop |> filter(id: stop.id) |> one() |> DB.read()
    assert unmoved.lat == stop.lat
    assert unmoved.lng == stop.lng
  end

  # The line joins the pins, so it follows one that is being carried, before anything is
  # written.
  feature "the route follows a pin that is being carried", %{session: session, trip: trip} do
    # Kyoto, west, on the first day.
    west =
      create_stop(trip,
        date: ~D[2026-03-28],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari"
      )

    # Tokyo, east, on the second - so the line runs west to east.
    create_stop(trip, date: ~D[2026-03-29], lat: 35.6762, lng: 139.6503, name: "Shibuya crossing")

    session =
      session
      |> sign_in(trip)
      |> assert_has(css(".pin", count: 2))

    [{first_before, _first_y}, {second, _second_y}] = route_points(session)

    # Picked up and carried east of Tokyo, and still held.
    session = press_pin(session, {".pin", "Fushimi Inari"}, {820, 300})

    # The line already bends: its first point has moved past the second, with the pointer
    # still down and nothing written.
    [{first_during, _first_y}, {^second, _second_y}] = route_points(session)
    assert first_during > first_before
    assert first_during > second

    held = Stop |> filter(id: west.id) |> one() |> DB.read()
    assert held.lng == west.lng

    # Letting go is what writes it, and the line stays where the hand left it.
    session = release_pointer(session, {820, 300})
    await_pending_writes(session, 0)

    [{first_after, _first_y}, {^second, _second_y}] = route_points(session)
    assert first_after > second

    moved = Stop |> filter(id: west.id) |> one() |> DB.read()
    assert moved.lng > west.lng
  end

  # Presses the only pin, carries the pointer to the given offset from the map's top left,
  # and lets go there.
  defp drag_pin(session, at) do
    session
    |> press_pin(".pin", at)
    |> release_pointer(at)
  end

  # Where each pin sits, as the percentages its own style carries.
  defp pin_positions(session) do
    session
    |> all(css(".pin"))
    |> Enum.map(fn pin ->
      style = Element.attr(pin, "style")

      [x, y] =
        Regex.scan(~r/([\d.]+)%/, style) |> Enum.map(fn [_all, n] -> String.to_float(n) end)

      {x, y}
    end)
  end

  # Presses the pin on itself and carries the pointer, leaving it down so a test can look at
  # the map mid-drag. The move goes to the document, which is where the page listens once a
  # drag is under way.
  defp press_pin(session, pin, at) do
    dispatch_pointer(session, [{:down, pin, :target}, {:move, :document, at}])
  end

  defp release_pointer(session, at) do
    dispatch_pointer(session, [{:up, :document, at}])
  end
end
