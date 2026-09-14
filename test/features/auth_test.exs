defmodule Offgrid.Features.AuthTest do
  use Offgrid.FeatureCase, async: false

  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

  # A trip, because the trip screen is where a face proves a session was made.
  setup do
    reset_data()

    [trip: create_trip()]
  end

  feature "signs up, logs out and comes back", %{session: session, trip: trip} do
    session
    |> sign_up("Nora Vale", "nora@offgrid.test")
    # Signing up leaves you signed in on your trips list, empty for a new account. The trip
    # screen shows the proof: the initials derived from the name.
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
    |> assert_text(css(".faces"), "NV")
    # Logging out from the list, which is where somebody with no trip open would look for it.
    |> visit(TripsPage)
    |> click(button("Log out"))
    |> assert_page(LogInPage)
    |> log_in("nora@offgrid.test")
    |> visit(TripPage, id: trip.id)
    |> assert_text(css(".faces"), "NV")
  end

  feature "signs up on Enter", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css("#sign_up_name"), with: "Nora Vale")
    |> fill_in(css("#sign_up_email"), with: "nora@offgrid.test")
    |> fill_in(css("#sign_up_password"), with: password())
    |> send_keys([:enter])
    |> assert_page(TripsPage)
  end

  feature "logs in on Enter", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css("#log_in_email"), with: "nora@offgrid.test")
    |> fill_in(css("#log_in_password"), with: password())
    |> send_keys([:enter])
    |> assert_page(TripsPage)
  end

  feature "asks for a name on the sign-up card", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css("#sign_up_email"), with: "nora@offgrid.test")
    |> fill_in(css("#sign_up_password"), with: password())
    |> click(button("Create account"))
    |> assert_text(css(".card"), "Tell us your name.")
    |> assert_page(SignUpPage)
  end

  # Its own feature on a fresh browser, because revisiting the card lets the browser refill
  # the field.
  feature "asks for an email on the sign-up card", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css("#sign_up_name"), with: "Nora Vale")
    |> fill_in(css("#sign_up_password"), with: password())
    |> click(button("Create account"))
    |> assert_text(css(".card"), "Enter your email.")
    |> assert_page(SignUpPage)
  end

  feature "wants a real password", %{session: session} do
    session
    |> sign_up("Nora Vale", "nora@offgrid.test", "short")
    |> assert_text(css(".card"), "Choose a password of at least 8 characters.")
    |> assert_page(SignUpPage)
    # Nothing was written for the short one: the same address goes through afterwards.
    |> fill_in(css("#sign_up_password"), with: password())
    |> click(button("Create account"))
    |> assert_page(TripsPage)
  end

  feature "refuses an email somebody already signed up with", %{session: session, trip: trip} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> sign_up("Tom Reyes", "nora@offgrid.test")
    |> assert_text(css(".card"), "That email is already taken.")
    |> assert_page(SignUpPage)
    # With no session, the gate sends the trip screen back to the card.
    |> visit("/trips/#{trip.id}")
    |> assert_page(LogInPage)
  end

  feature "logs out from the trip screen and stays out", %{session: session, trip: trip} do
    session
    |> sign_in(trip)
    |> assert_text(css(".faces"), "NV")
    |> click(button("Log out"))
    |> assert_page(LogInPage)
    # The session went with it, so the trip it was on is behind the card again.
    |> visit("/trips/#{trip.id}")
    |> assert_page(LogInPage)
  end

  feature "sends a signed-in visitor at the root to their trips", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> log_in("nora@offgrid.test")
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
    |> log_in("nora@offgrid.test")
    |> visit("/log-in")
    |> assert_page(TripsPage)
    |> visit("/sign-up")
    |> assert_page(TripsPage)
  end

  feature "refuses a password that does not match", %{session: session, trip: trip} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css("#log_in_email"), with: "nora@offgrid.test")
    |> fill_in(css("#log_in_password"), with: "not-the-password")
    |> click(button("Log in"))
    |> assert_text(css(".card"), "Wrong email or password.")
    |> assert_page(LogInPage)
    # Asking for the trip screen proves no session was made: with none, the gate sends you
    # back to the card.
    |> visit("/trips/#{trip.id}")
    |> assert_page(LogInPage)
  end

  feature "refuses an address nobody registered, in the same words", %{session: session} do
    create_user("Nora Vale", "nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css("#log_in_email"), with: "stranger@offgrid.test")
    |> fill_in(css("#log_in_password"), with: password())
    |> click(button("Log in"))
    # The same sentence the wrong-password case gets. Saying "no such account" here would
    # tell whoever is guessing which addresses are worth guessing at.
    |> assert_text(css(".card"), "Wrong email or password.")
    |> assert_page(LogInPage)
  end
end
