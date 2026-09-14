defmodule Offgrid.Features.TripPageTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

  setup do
    reset_data()

    [trip: create_trip()]
  end

  describe "itinerary" do
    feature "shows only the stops of the trip in the address", %{session: session, trip: trip} do
      other_trip =
        %{
          basemap_id: trip.basemap_id,
          ends_on: ~D[2026-05-17],
          name: "Warsaw, long weekend",
          starts_on: ~D[2026-05-15]
        }
        |> Trip.new()
        |> DB.create!()

      create_stop(trip, date: ~D[2026-03-28], name: "Fushimi Inari")
      create_stop(other_trip, date: ~D[2026-05-15], name: "Old Town at dusk")

      session = sign_in(session, trip)

      # A member of BOTH, so that what keeps the two itineraries apart is the address and not
      # the policy. Being on one trip and not the other would prove nothing about scoping.
      :ok = Auth.grant_role(signed_in_user(), other_trip, :member)

      session
      # The header names the trip in the address.
      |> assert_text(css(".lp-title"), "Japan, blossom run")
      |> assert_text(css(".lp-dates"), "28 MAR – 6 APR")
      |> assert_text(css(".lpanel"), "Fushimi Inari")
      |> refute_has(css(".stop", text: "Old Town at dusk"))
      |> visit(TripPage, id: other_trip.id)
      |> assert_text(css(".lp-title"), "Warsaw, long weekend")
      |> assert_text(css(".lp-dates"), "15 – 17 MAY")
      |> assert_text(css(".lpanel"), "Old Town at dusk")
      |> refute_has(css(".stop", text: "Fushimi Inari"))
    end
  end

  describe "calendar" do
    feature "offers no days for a trip whose dates crossed", %{session: session, trip: trip} do
      # Two offline browsers can still cross them - one moves the start, the other the end, and
      # the last write wins per column - so a crossed pair is a state the calendar has to
      # survive.
      :ok = DB.update(Trip, trip.id, %{ends_on: ~D[2026-03-28], starts_on: ~D[2026-04-06]})

      create_stop(trip, date: ~D[2026-03-28], name: "Fushimi Inari")

      session
      |> sign_in(trip)
      |> click(css(".stop", text: "Fushimi Inari"))
      |> assert_text(css(".ed-title"), "Fushimi Inari")
      |> refute_has(css(".cal button"))
      |> refute_has(css("#hologram-uncaught-error-overlay"))
    end

    feature "offers the days of the trip you are on, and its stops",
            %{session: session, trip: trip} do
      other_trip =
        %{
          basemap_id: trip.basemap_id,
          ends_on: ~D[2026-05-17],
          name: "Warsaw, long weekend",
          starts_on: ~D[2026-05-15]
        }
        |> Trip.new()
        |> DB.create!()

      create_stop(trip, date: ~D[2026-03-28], name: "Fushimi Inari")
      create_stop(other_trip, date: ~D[2026-05-15], name: "Old Town at dusk")

      session = sign_in(session, trip)
      :ok = Auth.grant_role(signed_in_user(), other_trip, :member)

      # Japan runs 28 Mar to 6 Apr: ten days, and a dot on the one that has a stop.
      session
      |> click(css(".stop", text: "Fushimi Inari"))
      |> assert_has(css(".cal button", count: 10))
      |> assert_has(css(".cal .dt i", count: 1))

      # Warsaw runs three days, and its calendar knows nothing of Japan's stop.
      session
      |> visit(TripPage, id: other_trip.id)
      |> click(css(".stop", text: "Old Town at dusk"))
      |> assert_has(css(".cal button", count: 3))
      |> assert_has(css(".cal .dt i", count: 1))
    end
  end

  describe "trip details" do
    feature "renames a trip and moves its dates from its own card",
            %{session: session, trip: trip} do
      session
      |> sign_in(trip)
      |> assert_text(css(".lp-title"), "Japan, blossom run")
      |> click(css(".lp-title"))
      |> fill_in(css("#details_name"), with: "Japan, cherry run")
      # The header behind the card is a second component reading the same row, so it renames
      # itself in the same frame - nothing was passed between them.
      |> assert_text(css(".lp-title"), "Japan, cherry run")
      |> fill_date("details_starts_on", "2026-03-30")
      |> assert_text(css(".lp-dates"), "30 MAR – 6 APR")
      # A start moved past the end takes the end with it: a trip is never backwards, and nobody
      # is told to edit the other field first.
      |> fill_date("details_starts_on", "2026-04-10")
      |> assert_text(css(".lp-dates"), "10 – 10 APR")
      |> send_keys([:escape])
      |> refute_has(css(".card"))
      |> await_pending_writes(0)
      # Read back from the server, so the card wrote a row rather than a screen.
      |> visit(TripPage, id: trip.id)
      |> assert_text(css(".lp-title"), "Japan, cherry run")
      |> assert_text(css(".lp-dates"), "10 – 10 APR")
    end

    feature "moves a trip's end from its own card", %{session: session, trip: trip} do
      create_stop(trip, date: ~D[2026-03-28], name: "Fushimi Inari")

      session
      |> sign_in(trip)
      |> assert_text(css(".lp-dates"), "28 MAR – 6 APR")
      |> click(css(".lp-title"))
      |> fill_date("details_ends_on", "2026-04-02")
      |> assert_text(css(".lp-dates"), "28 MAR – 2 APR")
      |> send_keys([:escape])
      |> refute_has(css(".card"))
      # The calendar reads the same row, so it offers the shorter trip: 28 Mar to 2 Apr.
      |> click(css(".stop", text: "Fushimi Inari"))
      |> assert_has(css(".cal button", count: 6))
      |> assert_text(css(".cal button:last-child .nm"), "2")
      |> await_pending_writes(0)
      |> visit(TripPage, id: trip.id)
      |> assert_text(css(".lp-dates"), "28 MAR – 2 APR")
    end

    feature "an organizer deletes a trip that has an itinerary, remarks and ink",
            %{session: session, trip: trip} do
      stop = create_stop(trip, date: ~D[2026-03-28], name: "Fushimi Inari")
      tom = create_user("Tom Reyes", "tom@offgrid.test")

      create_comment(tom, stop, "Before eight.")
      create_sketch(tom, trip, color: "#30b0c7")

      session
      |> sign_in(trip, role: :organizer)
      |> assert_text(css(".lpanel"), "Fushimi Inari")
      |> click(css(".lp-title"))
      |> click(button("Delete trip"))
      |> assert_page(TripsPage)
      |> await_pending_writes(0)
      |> assert_text(css(".card"), "No trips yet")

      # Everything that named the trip or one of its stops went with it. References restrict
      # rather than cascade, so a row left behind means the server refused the batch.
      assert DB.read(Trip) == []
      assert DB.read(Stop) == []
      assert DB.read(Comment) == []
      assert DB.read(Sketch) == []
    end

    feature "shows a member the trip card without a way to delete it",
            %{session: session, trip: trip} do
      session
      |> sign_in(trip)
      |> click(css(".lp-title"))
      |> assert_text(css(".card"), "Trip details")
      |> refute_has(button("Delete trip"))
    end
  end

  describe "map picker" do
    feature "draws the map the trip is on, and changes it", %{session: session, trip: trip} do
      create_basemap("Alps", "alps")

      session
      |> sign_in(trip)
      # Japan, because that is the basemap the trip was made on.
      |> assert_has(css(".terrain.japan"))
      |> click(css(".swatch"))
      # Upper case because `.thumb b` is text-transform: uppercase and a browser reports what it
      # rendered.
      |> click(css(".thumb", text: "ALPS"))
      # One local write, and the map behind the panel is drawn from the row it changed - no
      # round trip between the click and the new terrain.
      |> assert_has(css(".terrain.alps"))
      |> refute_has(css(".terrain.japan"))
      |> await_pending_writes(0)
      # And it was a real write, not a screen that only agrees with itself: the reload reads
      # the trip back from the server.
      |> visit(TripPage, id: trip.id)
      |> assert_has(css(".terrain.alps"))
    end
  end

  # The person `sign_in/3` made and signed the browser in as, a member by default.
  defp signed_in_user do
    User
    |> filter(email: "member@offgrid.test")
    |> one()
    |> DB.read()
  end
end
