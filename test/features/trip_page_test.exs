defmodule Offgrid.Features.TripPageTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Hologram.DB.Connection
  alias Hologram.DB.Mapper
  alias Offgrid.Entities.Stop
  alias Offgrid.Pages.TripPage

  setup do
    {:ok, _result} =
      Connection.query(~s(TRUNCATE "hologram_data"."#{Mapper.table_name(Stop)}"), [])

    :ok
  end

  feature "renders the stops the database holds", %{session: session} do
    %{date: ~D[2026-03-28], name: "Fushimi Inari"}
    |> Stop.new()
    |> DB.create!()

    session
    |> visit(TripPage)
    |> assert_text(css(".lpanel"), "Fushimi Inari")
  end
end
