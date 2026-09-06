defmodule Offgrid.Features.StopCrudTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

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

  @sessions 2
  feature "closes the editor when somebody else deletes the stop",
          %{sessions: [nora, tom], trip: trip} do
    %{date: ~D[2026-03-29], name: "Ryokan", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    nora = sign_in_as_member(nora, trip)
    tom = sign_in_as(tom, trip, "Tom Reyes", "tom@offgrid.test")

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

  defp sign_in_as(session, trip, name, email) do
    user =
      %{email: email, name: name, password_hash: Bcrypt.hash_pwd_salt("hakone-2026")}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(user, trip, :member)

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: email)
    |> fill_in(css(".card .inp", at: 1), with: "hakone-2026")
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
  end
end
