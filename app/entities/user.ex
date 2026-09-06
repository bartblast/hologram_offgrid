defmodule Offgrid.Entities.User do
  use Hologram.Entity, user: true

  # min_length, because an empty string satisfies required: without the floor an account with
  # no name and no address is a valid row, and the unique index then refuses the second one.
  attribute :email, :string, min_length: 1, unique: true
  attribute :name, :string, min_length: 1
  attribute :password_hash, :string, server_only: true

  # Reading is open because a trip has to show who is on it. Nothing else is, and the
  # ABSENCE of a :create rule is the enforcement: no browser can open an account, because
  # there is no grant for one to use. The sign-up command writes past this by claiming the
  # server's own authority with trust/1, which a client cannot do - a claim is put on the
  # struct by server code, and a client's batch carries field values and never a claim.
  # The hash is server_only, so it is stripped before any row reaches a browser - an open
  # read never exposes it.
  allow :read
end
