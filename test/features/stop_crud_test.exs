defmodule Offgrid.Features.StopCrudTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Offgrid.Entities.Stop

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "adds a stop, renames it, moves it to another day, times it and deletes it", %{
    session: session,
    trip: trip
  } do
    %{date: ~D[2026-03-28], name: "Haneda arrival", time: ~T[09:00:00], trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    session
    |> sign_in_as_member(trip)
    |> assert_text(css(".lpanel"), "Haneda arrival")
    |> assert_has(css(".day", count: 1))
    |> refute_has(css(".pin"))
    # + arms the map rather than creating anything. Pointing at the map is what creates.
    |> click(css(".addb"))
    |> assert_has(css(".addb.on"))
    |> click(css("#canvas"))
    # The new stop lands on the first day of the trip, opens its own editor, and is pinned
    # where the click fell - all from one local write, before anything travels.
    |> assert_text(css(".ed-title"), "New stop")
    |> assert_text(css(".ed-sub"), "Sat 28 Mar")
    |> assert_has(css(".pin.mine", count: 1))
    |> refute_has(css(".addb.on"))
    |> fill_in(css(".editor .inp", at: 0), with: "Tsukiji breakfast")
    # The title reads the same row the list does, so renaming shows up in both at once.
    |> assert_text(css(".ed-title"), "Tsukiji breakfast")
    |> assert_text(css(".stop.open"), "Tsukiji breakfast")
    # Picking a day is the only way a stop moves - nothing is dragged, and no position is
    # stored. A second day heading appearing is the list re-deriving its own grouping.
    |> click(css(".cal button", text: "30"))
    |> assert_text(css(".ed-sub"), "Mon 30 Mar")
    |> assert_text(css(".lpanel"), "Mon 30 Mar")
    |> assert_has(css(".day", count: 2))
    |> click(css(".times button", text: "14:30"))
    |> assert_text(css(".stop.open"), "14:30")
    |> click(button("Delete stop"))
    # Deleting closes the editor and collapses the day it was the only stop of.
    |> refute_has(css(".editor"))
    |> assert_has(css(".day", count: 1))
    |> refute_has(css(".lpanel", text: "Tsukiji breakfast"))
    |> assert_text(css(".lpanel"), "Haneda arrival")
  end

  feature "places nothing until armed, and Escape disarms", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    # Unarmed, the map is just a map.
    |> click(css("#canvas"))
    |> refute_has(css(".editor"))
    |> click(css(".addb"))
    |> assert_has(css(".addb.on"))
    |> send_keys([:escape])
    |> refute_has(css(".addb.on"))
    |> click(css("#canvas"))
    |> refute_has(css(".editor"))
    |> refute_has(css(".pin"))
  end
end
