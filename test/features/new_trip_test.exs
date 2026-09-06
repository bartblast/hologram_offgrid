defmodule Offgrid.Features.NewTripTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User
  alias Offgrid.Pages.NewTripPage
  alias Offgrid.Pages.TripsPage

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "starts a trip with no network and keeps it", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> visit(TripsPage)
    |> click(link("New trip"))
    |> assert_page(NewTripPage)
    |> fill_in(css(".card .inp", at: 0), with: "Warsaw, long weekend")
    |> fill_date("starts_on", "2026-05-15")
    |> fill_date("ends_on", "2026-05-18")
    |> click(css(".thumbs .thumb", at: 0))
    # Nothing this browser writes can reach the server from here on, so anything that shows
    # up afterwards was written locally and read back locally.
    |> hold_mutation_requests()
    |> click(button("Create trip"))
    # Straight onto the trip, which is a stronger claim than a row in a list: the screen was
    # reached BY ITS ID and drawn from a row the server has never heard of.
    |> assert_text(css(".lp-title"), "Warsaw, long weekend")
    |> assert_text(css(".lp-dates"), "15 – 18 MAY")
    # And it survives the network coming back, rather than being replaced or dropped.
    |> release_mutations()
    |> await_pending_writes(0)
    |> assert_text(css(".lp-title"), "Warsaw, long weekend")
    |> visit(TripsPage)
    |> assert_text(css(".card"), "Warsaw, long weekend")
    |> assert_text(css(".card"), "Japan, blossom run")
  end

  feature "starts a trip offline with people already on it", %{session: session, trip: trip} do
    anna =
      %{email: "anna@offgrid.test", name: "Anna Kim", password_hash: "x"}
      |> User.new()
      |> DB.create!()

    session
    |> sign_in_as_member(trip)
    |> visit(NewTripPage)
    |> fill_in(css(".card .inp", at: 0), with: "Alps, hut to hut")
    |> fill_date("starts_on", "2026-08-02")
    |> fill_date("ends_on", "2026-08-09")
    |> click(css(".thumbs .thumb", at: 0))
    # Finding Anna by her address is a local query - every account syncs - so this works with
    # the network already held.
    |> hold_mutation_requests()
    |> fill_in(css(".card .inp", at: 3), with: "anna@offgrid.test")
    |> send_keys([:enter])
    |> assert_text(css(".chips"), "anna@offgrid.test")
    |> click(button("Create trip"))
    |> assert_text(css(".lp-title"), "Alps, hut to hut")
    # The people came with it: the panel names Anna before anything has travelled.
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Anna Kim")
    |> release_mutations()
    # Zero pending batches is what says the server has answered - the trip being on screen
    # before this only proves the browser wrote it.
    |> await_pending_writes(0)
    |> assert_text(css(".lp-title"), "Alps, hut to hut")

    # The trip and the grant it carried both landed, so Anna is on it.
    alps =
      Trip
      |> filter(name: "Alps, hut to hut")
      |> one()
      |> DB.read()

    assert Auth.can?(anna.id, :read, alps)
  end

  feature "refuses an address nobody here uses", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> visit(NewTripPage)
    |> fill_in(css(".card .inp", at: 3), with: "stranger@offgrid.test")
    |> send_keys([:enter])
    |> assert_text(css(".card"), "Nobody here uses that address.")
  end

  feature "refuses a trip with no name", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> visit(NewTripPage)
    |> fill_date("starts_on", "2026-05-15")
    |> fill_date("ends_on", "2026-05-18")
    |> click(css(".thumbs .thumb", at: 0))
    |> click(button("Create trip"))
    |> assert_text(css(".card"), "Give the trip a name.")
    |> assert_page(NewTripPage)
  end

  feature "refuses a trip with no map", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> visit(NewTripPage)
    |> fill_in(css(".card .inp", at: 0), with: "Alps, hut to hut")
    |> fill_date("starts_on", "2026-08-02")
    |> fill_date("ends_on", "2026-08-09")
    |> click(button("Create trip"))
    |> assert_text(css(".card"), "Pick a map.")
    |> assert_page(NewTripPage)
  end
end
