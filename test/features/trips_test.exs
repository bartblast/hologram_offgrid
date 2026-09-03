defmodule Offgrid.Features.TripsTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.NewTripPage
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

  @password "hakone-2026"

  setup do
    truncate_trip_data()

    [basemap: create_basemap("Japan", "japan")]
  end

  # Two browsers, two accounts, and nothing between them but the sync: what one writes the
  # other reads, and what one takes away the other loses. This is the beat the talk is built
  # around, so it is a test rather than a rehearsal.
  @sessions 2
  feature "puts a trip on somebody else's screen, and takes it back off",
          %{sessions: [anna, bart]} do
    # Anna first, so that her account is already on Bart's browser when he types her address.
    # Finding a person by email is a local query - every account syncs - and it can only find
    # somebody the browser has heard of.
    anna = sign_up(anna, "Anna Kim", "anna@offgrid.test")
    bart = sign_up(bart, "Bart Blast", "bart@offgrid.test")

    bart
    |> visit(NewTripPage)
    |> fill_in(css(".card .inp", at: 0), with: "Japan, blossom run")
    |> fill_date("starts_on", "2026-03-28")
    |> fill_date("ends_on", "2026-04-06")
    |> click(css(".thumbs .thumb", at: 0))
    |> fill_in(css(".card .inp", at: 3), with: "anna@offgrid.test")
    |> send_keys([:enter])
    |> assert_text(css(".chips"), "anna@offgrid.test")
    |> click(button("Create trip"))
    |> assert_page(TripsPage)

    # Anna never asked for it. The trip materialises on her list because the grant Bart wrote
    # reached her browser, and her list is a query that re-ran.
    assert_text(anna, css(".rowlist"), "Japan, blossom run")

    anna
    |> click(css(".triprow"))
    |> assert_page(TripPage, id: trip_id())
    |> assert_text(css(".lp-title"), "Japan, blossom run")

    bart
    |> visit(TripPage, id: trip_id())
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Anna Kim")
    |> click(css(".mrow u"))
    |> await_pending_writes(0)

    # Anna is still standing on the trip's own page and loses it under her feet: the grant is
    # gone, so the rows it let her read are gone with it.
    refute_has(anna, css(".lp-title"))

    anna
    |> visit(TripsPage)
    |> assert_text(css(".card"), "No trips yet")
  end

  defp sign_up(session, name, email) do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 0), with: name)
    |> fill_in(css(".card .inp", at: 1), with: email)
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> click(button("Create account"))
    |> assert_page(TripsPage)
  end

  # The one trip the test made. Read from the server rather than carried, because the browser
  # that made it never named it to us.
  defp trip_id do
    Trip
    |> order_by(:created_at)
    |> one()
    |> DB.read()
    |> Map.fetch!(:id)
  end
end
