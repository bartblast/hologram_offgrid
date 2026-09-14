defmodule Offgrid.Entities.User do
  @moduledoc """
  An account. Reading is open because a trip shows who is on it, and the password hash is
  `server_only`, so it never reaches a browser.

  There is no `:create` rule, so no browser can open an account. The sign-up command creates
  one with `trust/1`, which only server code can apply.
  """

  use Hologram.Entity, user: true

  # min_length, because an empty string satisfies required, and without it the unique index
  # would refuse the second account with an empty email.
  attribute :email, :string, min_length: 1, unique: true
  attribute :name, :string, min_length: 1
  attribute :password_hash, :string, server_only: true

  allow :read

  @doc """
  Returns the first letter of each of the first two words of the user's name, upper case:
  "Nora Vale" is "NV".
  """
  @spec initials(t) :: String.t()
  def initials(user) do
    user.name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end
end
