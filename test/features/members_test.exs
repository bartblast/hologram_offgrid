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

  feature "an organizer removes somebody from the trip", %{session: session, trip: trip} do
    anna =
      %{email: "anna@offgrid.test", name: "Anna Kim", password_hash: "x"}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(anna, trip, :member)

    session
    |> sign_in_as_organizer(trip)
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Anna Kim")
    # The only cross on screen is Anna's - an organizer's own row carries none.
    |> click(css(".mrow u"))
    # Gone from the panel without a round trip, and the organizer is who is left.
    |> assert_has(css(".mrow", count: 1))
    |> assert_text(css(".members"), "Iris Kalm")
    |> refute_has(css(".mrow u"))
    |> assert_text(css(".members"), "Iris Kalm")
    |> refute_has(css(".mrow u"))
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

  feature "shows a person holding two roles once", %{session: session, trip: trip} do
    anna =
      %{email: "anna@offgrid.test", name: "Anna Kim", password_hash: "x"}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(anna, trip, :member)
    :ok = Auth.grant_role(anna, trip, :organizer)

    session
    # Signing in grants this browser's user :member on the trip.
    |> sign_in_as_member(trip)
    |> click(css(".facepile"))
    # Anna and Nora - not Anna twice and Nora, which is what the grant store holds.
    |> assert_has(css(".mrow", count: 2))
    |> assert_text(css(".members"), "Anna Kim")
    # The stronger of Anna's two roles is the one that survives.
    |> assert_text(css(".members"), "ORGANIZER")
  end

  feature "shows a member the list without the remove controls", %{session: session, trip: trip} do
    anna =
      %{email: "anna@offgrid.test", name: "Anna Kim", password_hash: "x"}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(anna, trip, :member)

    session
    |> sign_in_as_member(trip)
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Anna Kim")
    # A member sees who is on the trip and cannot change it, which the browser decides for
    # itself from the grants it holds.
    |> refute_has(css(".mrow u"))
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
