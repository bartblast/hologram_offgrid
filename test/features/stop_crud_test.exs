defmodule Offgrid.Features.StopCrudTest do
  use Offgrid.FeatureCase, async: false

  setup do
    reset_data()

    [trip: create_trip()]
  end

  feature "adds a stop, renames it, moves it to another day, times it and deletes it", %{
    session: session,
    trip: trip
  } do
    create_stop(trip, date: ~D[2026-03-28], name: "Haneda arrival", time: ~T[09:00:00])

    session
    |> sign_in(trip)
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
    |> fill_in(css("#stop_name"), with: "Tsukiji breakfast")
    # The title reads the same row the list does, so renaming shows up in both at once.
    |> assert_text(css(".ed-title"), "Tsukiji breakfast")
    |> assert_text(css(".stop.open"), "Tsukiji breakfast")
    # Picking a day moves the stop in the itinerary. A second day heading appearing is the
    # list re-deriving its own grouping.
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

  @sessions 2
  feature "closes the editor when somebody else deletes the stop",
          %{sessions: [nora, tom], trip: trip} do
    create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    nora
    |> click(css(".stop", text: "Ryokan"))
    |> assert_text(css(".ed-title"), "Ryokan")

    tom
    |> click(css(".stop", text: "Ryokan"))
    |> click(button("Delete stop"))
    |> refute_has(css(".editor"))

    # The row went out from under Nora's open editor. The editor closes rather than dying on a
    # stop that is no longer there - which is the overlay a crash would have put on screen.
    nora
    |> refute_has(css(".editor"))
    |> refute_has(css("#hologram-uncaught-error-overlay"))
    |> refute_has(css(".stop", text: "Ryokan"))
  end

  feature "closes the editor from its own button", %{session: session, trip: trip} do
    create_stop(trip, date: ~D[2026-03-28], name: "Haneda arrival")

    session
    |> sign_in(trip)
    |> click(css(".stop", text: "Haneda arrival"))
    |> assert_text(css(".ed-title"), "Haneda arrival")
    |> click(css(".ed-close"))
    # Gone, and the stop it was open on is still on the itinerary - closing is not deleting.
    |> refute_has(css(".editor"))
    |> assert_text(css(".lpanel"), "Haneda arrival")
  end

  feature "places nothing until armed, and Escape disarms", %{session: session, trip: trip} do
    session
    |> sign_in(trip)
    # Unarmed, a click on the map is a ping - and the ping appearing is what proves the click
    # was handled before the editor is looked for.
    |> click(css("#canvas"))
    |> assert_has(css(".ping"))
    |> refute_has(css(".editor"))
    # Faded, so the next ping is a new one.
    |> refute_has(css(".ping"))
    |> click(css(".addb"))
    |> assert_has(css(".addb.on"))
    |> send_keys([:escape])
    |> refute_has(css(".addb.on"))
    |> click(css("#canvas"))
    |> assert_has(css(".ping"))
    |> refute_has(css(".editor"))
    |> refute_has(css(".pin"))
  end
end
