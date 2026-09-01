defmodule Offgrid.Features.AuthTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.Auth.RoleGrant
  alias Hologram.DB
  alias Hologram.DB.Connection
  alias Hologram.DB.Mapper
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripPage

  @password "hakone-2026"

  # Both tables in one statement: the grant store holds two foreign keys into the user
  # table, and PostgreSQL refuses to truncate a table something references unless the
  # referencing one goes with it.
  setup do
    tables =
      Enum.map_join([RoleGrant, User], ", ", fn entity_type ->
        ~s("hologram_data"."#{Mapper.table_name(entity_type)}")
      end)

    {:ok, _result} = Connection.query("TRUNCATE #{tables}", [])

    :ok
  end

  feature "signs up, logs out and comes back", %{session: session} do
    session
    |> visit(SignUpPage)
    |> fill_in(css(".card .inp", at: 0), with: "Nora Vale")
    |> fill_in(css(".card .inp", at: 1), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 2), with: @password)
    |> click(button("Create account"))
    # Signing up leaves you signed in, so the trip screen carries the face the name derives
    # - NV rather than either of the two placeholder faces beside it.
    |> assert_page(TripPage)
    |> assert_text(css(".faces"), "NV")
    |> click(button("Log out"))
    |> assert_page(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: "nora@offgrid.test")
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripPage)
    |> assert_text(css(".faces"), "NV")
  end

  feature "refuses a password that does not match", %{session: session} do
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
    |> visit(TripPage)
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
