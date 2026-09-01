defmodule Offgrid.Entities.User do
  use Hologram.Entity, user: true

  attribute :email, :string, unique: true
  attribute :name, :string
  attribute :password_hash, :string, server_only: true

  # Reading is open because a trip has to show who is on it. Nothing else is: accounts are
  # created and changed by commands, which run on the server as trusted code and so write
  # without asking a policy. The hash is server_only, so it is stripped before any row
  # reaches a browser - an open read never exposes it.
  allow :read
end
