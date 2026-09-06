defmodule Offgrid.Features.AuthTest do
  use Offgrid.FeatureCase, async: false

  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

  @password "hakone-2026"

  # A trip, because the trip screen is where a face proves a session was made, and that screen
  # now needs one named in its address.
  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "signs up, logs out and comes back", %{session: session, trip: trip} do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 0), with: "Nora Vale")
    |> fill_in(css(".card .inp", at: 1), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> click(button("Create account"))
    # Signing up leaves you signed in and on your trips, which for a new account is none of
    # them. The trip screen is where the proof shows: it carries the face the name derives -
    # NV rather than either of the two placeholder faces beside it.
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
    |> assert_text(css(".faces"), "NV")
    # Logging out from the list, which is where somebody with no trip open would look for it.
    |> visit(TripsPage)
    |> click(button("Log out"))
    |> assert_page(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
    |> assert_text(css(".faces"), "NV")
  end

  feature "signs up on Enter", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 0), with: "Nora Vale")
    |> fill_in(css(".card .inp", at: 1), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> send_keys([:enter])
    |> assert_page(TripsPage)
  end

  feature "logs in on Enter", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> send_keys([:enter])
    |> assert_page(TripsPage)
  end

  feature "asks for a name on the sign-up card", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 1), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> click(button("Create account"))
    |> assert_text(css(".card"), "Tell us your name.")
    |> assert_page(SignUpPage)
  end

  # Its own feature on its own browser rather than a second try on the card above: opening
  # the same address again let the browser put the typed address back into the field, and
  # the card went through.
  feature "asks for an email on the sign-up card", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 0), with: "Nora Vale")
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> click(button("Create account"))
    |> assert_text(css(".card"), "Enter your email.")
    |> assert_page(SignUpPage)
  end

  feature "wants a real password", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 0), with: "Nora Vale")
    |> fill_in(css(".card .inp", at: 1), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 2), with: "short")
    |> click(button("Create account"))
    |> assert_text(css(".card"), "Choose a password of at least 8 characters.")
    |> assert_page(SignUpPage)
    # Nothing was written for the short one: the same address goes through afterwards.
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> click(button("Create account"))
    |> assert_page(TripsPage)
  end

  feature "sends a signed-in visitor at the root to their trips", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    # The root is a door, not a page: it never renders, so what proves it is where you end up.
    |> visit("/")
    |> assert_page(TripsPage)
  end

  feature "sends a visitor at the root with no session to the log-in card", %{session: session} do
    session
    |> visit("/")
    |> assert_page(LogInPage)
  end

  feature "keeps a visitor with no session off every screen that needs one",
          %{session: session, trip: trip} do
    session
    |> visit("/trips")
    |> assert_page(LogInPage)
    |> visit("/trips/new")
    |> assert_page(LogInPage)
    |> visit("/trips/#{trip.id}")
    |> assert_page(LogInPage)
  end

  feature "keeps somebody already signed in off the cards for signing in", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    |> visit("/log-in")
    |> assert_page(TripsPage)
    |> visit("/sign-up")
    |> assert_page(TripsPage)
  end

  feature "refuses a password that does not match", %{session: session, trip: trip} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: "not-the-password")
    |> click(button("Log in"))
    |> assert_text(css(".card"), "Wrong email or password.")
    |> assert_page(LogInPage)
    # Asking for the trip screen is what proves no session was made: with none, the gate sends
    # you straight back to the card. Refuting the log-out control on the card itself would pass
    # whatever happened - that card never has one.
    |> visit("/trips/#{trip.id}")
    |> assert_page(LogInPage)
  end

  feature "refuses an address nobody registered, in the same words", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "stranger@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    # The same sentence the wrong-password case gets. Saying "no such account" here would
    # tell whoever is guessing which addresses are worth guessing at.
    |> assert_text(css(".card"), "Wrong email or password.")
    |> assert_page(LogInPage)
  end
end
