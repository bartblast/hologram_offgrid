defmodule Offgrid.Features.PingTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

  @password "hakone-2026"

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  # The one thing on this screen that is not a row: a ping is a gesture, so nothing stores it
  # and it leaves nothing behind.
  @sessions 2
  feature "points at a place on everyone else's map, and fades", %{
    sessions: [one, two],
    trip: trip
  } do
    one = sign_in_as_member(one, trip)
    two = sign_in_as(two, trip, "Tom Reyes", "tom@offgrid.test")

    # Unarmed, so a click on the map is a ping rather than a stop.
    one
    |> click(css("#canvas"))
    |> assert_has(css(".ping"))

    # It arrives on the other screen without anybody asking for it.
    assert_has(two, css(".ping"))

    # Nothing was written, and nothing is left after it fades.
    assert await_pending_writes(one, 0)
    assert length(DB.read(Offgrid.Entities.Stop)) == 0

    one |> refute_has(css(".ping"))
    two |> refute_has(css(".ping"))
  end

  @sessions 2
  feature "shows who else is on the trip, whoever arrived first",
          %{sessions: [one, two], trip: trip} do
    one = sign_in_as_member(one, trip)

    # Alone, the pill carries only your own face.
    one
    |> assert_text(css(".faces"), "NV")
    |> assert_has(css(".face", count: 1))

    two = sign_in_as(two, trip, "Tom Reyes", "tom@offgrid.test")

    # The arrival tells the room, and the room answers - so each sees the other without
    # either of them asking, and neither is listed twice.
    one
    |> assert_text(css(".faces"), "TR")
    |> assert_has(css(".face", count: 2))

    two
    |> assert_text(css(".faces"), "NV")
    |> assert_has(css(".face", count: 2))
  end

  defp sign_in_as(session, trip, name, email) do
    user =
      %{email: email, name: name, password_hash: Bcrypt.hash_pwd_salt(@password)}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(user, trip, :member)

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: email)
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
  end
end
