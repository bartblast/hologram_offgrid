defmodule Offgrid.Password do
  @moduledoc """
  Hashing the password an account is made with, and checking one at log in.

  Server code only: the hash is `server_only` on `Offgrid.Entities.User`, and Bcrypt is a
  native library no browser can run.
  """

  alias Offgrid.Entities.User

  @doc """
  Returns the salted hash to store for the given password.
  """
  @spec hash(String.t()) :: String.t()
  def hash(password), do: Bcrypt.hash_pwd_salt(password)

  @doc """
  Returns whether the given password is the given user's.

  With no user, as for an unknown email, it still spends a hash comparison before answering
  false, so a log in takes as long either way and the timing does not reveal which emails have
  accounts.
  """
  @spec valid?(User.t() | nil, String.t()) :: boolean
  def valid?(nil, _password) do
    Bcrypt.no_user_verify()

    false
  end

  def valid?(user, password), do: Bcrypt.verify_pass(password, user.password_hash)
end
