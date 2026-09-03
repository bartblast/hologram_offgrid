defmodule Offgrid.Features.TripPageTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User
  alias Offgrid.Pages.TripPage

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

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

    %{date: ~D[2026-03-28], name: "Fushimi Inari", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    %{date: ~D[2026-05-15], name: "Old Town at dusk", trip_id: other_trip.id}
    |> Stop.new()
    |> DB.create!()

    session = sign_in_as_member(session, trip)

    # A member of BOTH, so that what keeps the two itineraries apart is the address and not
    # the policy. Being on one trip and not the other would prove nothing about scoping.
    :ok = Auth.grant_role(signed_in_user(), other_trip, :member)

    session
    # The header names the trip in the address, not the one the mockup was drawn from.
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

  feature "renders the stops the database holds", %{session: session, trip: trip} do
    %{date: ~D[2026-03-28], name: "Fushimi Inari", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    session
    |> sign_in_as_member(trip)
    |> assert_text(css(".lpanel"), "Fushimi Inari")
  end

  # The person `sign_in_as_member/2` made and signed the browser in as.
  defp signed_in_user do
    User
    |> filter(email: "member@offgrid.test")
    |> one()
    |> DB.read()
  end
end
