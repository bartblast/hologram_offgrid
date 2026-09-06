defmodule Offgrid.Features.PinsTest do
  use Offgrid.FeatureCase, async: false

  use Hologram.DB

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

  feature "a pin can be picked up and put down somewhere else",
          %{session: session, trip: trip} do
    # Kyoto, west of the middle of the Japan map.
    stop =
      %{
        date: ~D[2026-03-28],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari",
        trip_id: trip.id
      }
      |> Stop.new()
      |> DB.create!()

    session =
      session
      |> sign_in_as_member(trip)
      |> assert_has(css(".pin", count: 1))

    [{before_x, _before_y}] = pin_positions(session)

    # Picked up and carried east, and let go there.
    session = drag_pin(session, {600, 300})

    # The pin is where it was let go, on screen and in the row - and further east than it was.
    [{after_x, _after_y}] = pin_positions(session)
    assert after_x > before_x

    assert await_pending_writes(session, 0)

    moved = Stop |> filter(id: stop.id) |> one() |> DB.read()
    assert moved.lng > stop.lng
    # It was carried, not re-created: the same row, with its name and day untouched.
    assert moved.name == "Fushimi Inari"
    assert moved.date == ~D[2026-03-28]
  end

  feature "a pin that is only clicked stays where it is", %{session: session, trip: trip} do
    stop =
      %{
        date: ~D[2026-03-28],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari",
        trip_id: trip.id
      }
      |> Stop.new()
      |> DB.create!()

    session
    |> sign_in_as_member(trip)
    |> click(css(".pin"))
    # A press that never moved is a click: the editor opens and nothing is written.
    |> assert_text(css(".ed-title"), "Fushimi Inari")
    |> await_pending_writes(0)

    unmoved = Stop |> filter(id: stop.id) |> one() |> DB.read()
    assert unmoved.lat == stop.lat
    assert unmoved.lng == stop.lng
  end

  # The line joins the pins, so it has to come with one that is being carried - and it has to
  # do it before anything is written, or the demo's whole claim is a round trip.
  feature "the route follows a pin that is being carried", %{session: session, trip: trip} do
    # Kyoto, west, on the first day.
    west =
      %{
        date: ~D[2026-03-28],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari",
        trip_id: trip.id
      }
      |> Stop.new()
      |> DB.create!()

    # Tokyo, east, on the second - so the line runs west to east.
    %{
      date: ~D[2026-03-29],
      lat: 35.6762,
      lng: 139.6503,
      name: "Shibuya crossing",
      trip_id: trip.id
    }
    |> Stop.new()
    |> DB.create!()

    session =
      session
      |> sign_in_as_member(trip)
      |> assert_has(css(".pin", count: 2))

    [first_before, second] = route_xs(session)

    # Picked up and carried east of Tokyo, and still held.
    session = press_pin(session, "Fushimi Inari", {820, 300})

    # The line already bends: its first point has moved past the second, with the pointer
    # still down and nothing written.
    [first_during, ^second] = route_xs(session)
    assert first_during > first_before
    assert first_during > second

    held = Stop |> filter(id: west.id) |> one() |> DB.read()
    assert held.lng == west.lng

    # Letting go is what writes it, and the line stays where the hand left it.
    session = release_pointer(session, {820, 300})
    assert await_pending_writes(session, 0)

    [first_after, ^second] = route_xs(session)
    assert first_after > second

    moved = Stop |> filter(id: west.id) |> one() |> DB.read()
    assert moved.lng > west.lng
  end

  # Presses the only pin, carries the pointer to the given offset from the map's top left,
  # and lets go there. The moves go to the document, which is where the page listens once a
  # drag is under way.
  defp drag_pin(session, {x, y}) do
    session
    |> press_pin({x, y})
    |> release_pointer({x, y})
  end

  defp press_pin(session, {x, y}), do: press_pin(session, nil, {x, y})

  # Presses the pin with the given label (or the only one) and carries the pointer, leaving it
  # down - so a test can look at the map mid-drag.
  defp press_pin(session, label, {x, y}) do
    finder =
      if label do
        "Array.from(document.querySelectorAll('.pin')).find(p => p.textContent.includes('#{label}'))"
      else
        "document.querySelector('.pin')"
      end

    execute_script(session, """
    const pin = #{finder};
    const box = document.getElementById('canvas').getBoundingClientRect();
    const at = (x, y) => ({bubbles: true, clientX: box.left + x, clientY: box.top + y});
    const from = pin.getBoundingClientRect();

    pin.dispatchEvent(new PointerEvent('pointerdown', {bubbles: true, clientX: from.left + 6, clientY: from.top + 6}));
    document.dispatchEvent(new PointerEvent('pointermove', at(#{x}, #{y})));
    """)

    session
  end

  defp release_pointer(session, {x, y}) do
    execute_script(session, """
    const box = document.getElementById('canvas').getBoundingClientRect();
    document.dispatchEvent(new PointerEvent('pointerup', {bubbles: true, clientX: box.left + #{x}, clientY: box.top + #{y}}));
    """)

    session
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
