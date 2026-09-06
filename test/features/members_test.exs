defmodule Offgrid.Features.MembersTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.Auth

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "an organizer adds somebody by email", %{session: session, trip: trip} do
    create_user("Anna Kim", "anna@offgrid.test")

    session
    |> sign_in_as_organizer(trip)
    |> click(css(".facepile"))
    # Anna has an account and no role on this trip, so she is nowhere in the list yet.
    |> assert_has(css(".mrow", count: 1))
    |> fill_in(css(".members .inp"), with: "anna@offgrid.test")
    |> send_keys([:enter])
    # The address became a person without asking the server - every account is already here.
    |> assert_text(css(".members"), "Anna Kim")
    |> assert_has(css(".mrow", count: 2))
  end

  feature "an organizer removes somebody from the trip", %{session: session, trip: trip} do
    anna = create_user("Anna Kim", "anna@offgrid.test")

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

  feature "names an address nobody uses", %{session: session, trip: trip} do
    session
    |> sign_in_as_organizer(trip)
    |> click(css(".facepile"))
    |> fill_in(css(".members .inp"), with: "nobody@offgrid.test")
    |> send_keys([:enter])
    |> assert_text(css(".members"), "Nobody here uses that address.")
    |> assert_has(css(".mrow", count: 1))
  end

  feature "opens and closes the list from the faces", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> refute_has(css(".members"))
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Nora Vale")
    # Your own row carries your own colour: you are here, looking at it.
    |> assert_has(css(".mrow i.y", count: 1))
    |> click(css(".facepile"))
    |> refute_has(css(".members"))
  end

  feature "shows a person holding two roles once", %{session: session, trip: trip} do
    anna = create_user("Anna Kim", "anna@offgrid.test")

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
    anna = create_user("Anna Kim", "anna@offgrid.test")

    :ok = Auth.grant_role(anna, trip, :member)

    session
    |> sign_in_as_member(trip)
    |> click(css(".facepile"))
    |> assert_text(css(".members"), "Anna Kim")
    # A member sees who is on the trip and cannot change it, which the browser decides for
    # itself from the grants it holds - neither the crosses nor the field to add by.
    |> refute_has(css(".mrow u"))
    |> refute_has(css(".members .inp"))
  end

  feature "shows everyone on the trip", %{session: session, trip: trip} do
    anna = create_user("Anna Kim", "anna@offgrid.test")

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

  feature "shows nothing to somebody with no role on the trip", %{session: session, trip: trip} do
    session
    |> sign_in_as_stranger(trip, "Mira Vale", "stranger@offgrid.test")
    # The trip's own rules answer the header too, so a stranger is not even told its name.
    |> refute_has(css(".lp-title"))
    # Opened, so that finding nothing is the policy answering and not the panel being shut.
    |> click(css(".facepile"))
    # The list is read through the trip's own rules, so a stranger is told nothing about who
    # is on it - not even that anybody is.
    |> refute_has(css(".mrow"))
    # The tools have nothing to work on either, and say so by doing nothing: no stop is placed,
    # nothing crashes, and the pen still arms.
    |> click(css(".addb"))
    |> click(css("#canvas"))
    |> refute_has(css(".editor"))
    |> refute_has(css("#hologram-uncaught-error-overlay"))
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
  end
end
