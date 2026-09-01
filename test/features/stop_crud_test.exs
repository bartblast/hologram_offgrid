defmodule Offgrid.Features.StopCrudTest do
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

  feature "adds a stop, renames it, moves it to another day, times it and deletes it", %{
    session: session
  } do
    %{date: ~D[2026-03-28], name: "Haneda arrival", time: ~T[09:00:00]}
    |> Stop.new()
    |> DB.create!()

    session
    |> visit(TripPage)
    |> assert_text(css(".lpanel"), "Haneda arrival")
    |> assert_has(css(".day", count: 1))
    |> click(css(".addb"))
    # The new stop lands on the first day of the trip and opens its own editor.
    |> assert_text(css(".ed-title"), "New stop")
    |> assert_text(css(".ed-sub"), "Sat 28 Mar")
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
end
