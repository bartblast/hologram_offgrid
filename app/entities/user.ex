defmodule Offgrid.Entities.User do
  use Hologram.Entity, user: true

  attribute :email, :string, unique: true
  attribute :name, :string
  attribute :password_hash, :string, server_only: true

  # Reading is open because a trip has to show who is on it. Nothing else is: accounts are
  # created and changed by commands. A command writes as trusted code only while nobody is
  # signed in - the controller runs it under whatever actor the session carries, so once
  # there is one the write is judged like any other, and no rule here grants :create. The
  # hash is server_only, so it is stripped before any row reaches a browser - an open read
  # never exposes it.
  allow :read
end
