defmodule Offgrid.Features.AuthTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Offgrid.Entities.User
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
    |> click(button("Log out"))
    |> assert_page(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
    |> assert_text(css(".faces"), "NV")
  end

  feature "sends a signed-in visitor at the root to their trips", %{session: session} do
    register("nora@offgrid.test")

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

  feature "refuses a password that does not match", %{session: session, trip: trip} do
    register("nora@offgrid.test")

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: "not-the-password")
    |> click(button("Log in"))
    |> assert_text(css(".card"), "Wrong email or password.")
    |> assert_page(LogInPage)
    # Asking the trip screen is what proves no session was made. Refuting the log-out
    # control on the log-in card would pass whatever happened - that card never has one.
    |> visit(TripPage, id: trip.id)
    |> refute_has(css(".signout"))
  end

  feature "refuses an address nobody registered, in the same words", %{session: session} do
    register("nora@offgrid.test")

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

  defp register(email) do
    %{email: email, name: "Nora Vale", password_hash: Bcrypt.hash_pwd_salt(@password)}
    |> User.new()
    |> DB.create!()
  end
end
