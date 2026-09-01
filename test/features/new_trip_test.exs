defmodule Offgrid.Features.NewTripTest do
  use Offgrid.FeatureCase, async: false

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
    |> assert_page(TripsPage)
    |> assert_text(css(".card"), "Warsaw, long weekend")
    # And it survives the network coming back, rather than being replaced or dropped.
    |> release_mutations()
    |> assert_text(css(".card"), "Warsaw, long weekend")
    |> assert_text(css(".card"), "Japan, blossom run")
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
