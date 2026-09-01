defmodule Offgrid.Features.TripPageTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Offgrid.Entities.Stop
  alias Offgrid.Pages.TripPage

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "renders the stops the database holds", %{session: session, trip: trip} do
    %{date: ~D[2026-03-28], name: "Fushimi Inari", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    session
    |> visit(TripPage)
    |> assert_text(css(".lpanel"), "Fushimi Inari")
  end
end
