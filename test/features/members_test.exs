defmodule Offgrid.Features.MembersTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.User
  alias Offgrid.Pages.TripPage

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "opens and closes the list from the faces", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> refute_has(css(".members"))
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Nora Vale")
    |> click(css(".facepile"))
    |> refute_has(css(".members"))
  end

  feature "shows everyone on the trip", %{session: session, trip: trip} do
    anna =
      %{email: "anna@offgrid.test", name: "Anna Kim", password_hash: "x"}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(anna, trip, :organizer)

    session
    # Signing in grants this browser's user :member on the trip.
    |> sign_in_as_member(trip)
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Anna Kim")
    |> assert_text(css(".members"), "Nora Vale")
    # Upper case because that is what is on the screen: `.mrow em` is text-transform:
    # uppercase, and a browser reports the text it rendered, not the text in the markup.
    |> assert_text(css(".members"), "ORGANIZER")
    |> assert_text(css(".members"), "MEMBER")
  end

  feature "shows nothing to somebody with no role on the trip", %{session: session} do
    password = "hakone-2026"

    stranger =
      %{
        email: "stranger@offgrid.test",
        name: "Mira Vale",
        password_hash: Bcrypt.hash_pwd_salt(password)
      }
      |> User.new()
      |> DB.create!()

    session
    |> visit(Offgrid.Pages.LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: stranger.email)
    |> fill_in(css(".card .inp", at: 1), with: password)
    |> click(button("Log in"))
    |> assert_page(TripPage)
    # Opened, so that finding nothing is the policy answering and not the panel being shut.
    |> click(css(".facepile"))
    # The list is read through the trip's own rules, so a stranger is told nothing about who
    # is on it - not even that anybody is.
    |> refute_has(css(".mrow"))
  end
end
