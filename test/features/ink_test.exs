defmodule Offgrid.Features.InkTest do
  use Offgrid.FeatureCase, async: false

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  # The stroke itself is not here: pointer bindings do not dispatch in this Hologram, so the
  # surface exists and takes the pointer while nothing can yet be drawn on it. What CAN be
  # tested is the mode, and the mode is what the two map buttons are really about.
  feature "the pen arms drawing, and the map can only be waiting for one thing",
          %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> refute_has(css(".pen.on"))
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
    # Arming the other one puts the pen away: the map is waiting for a place or for ink.
    |> click(css(".addb"))
    |> assert_has(css(".addb.on"))
    |> refute_has(css(".pen.on"))
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
    |> refute_has(css(".addb.on"))
    # Escape puts it away, the same key that disarms placing.
    |> send_keys([:escape])
    |> refute_has(css(".pen.on"))
    # And a click on the map places nothing while the pen was the armed one.
    |> refute_has(css(".pin"))
  end
end
