defmodule Offgrid.Entities.Trip do
  use Hologram.Entity

  alias Offgrid.Entities.Basemap

  attribute :ends_on, :date
  attribute :name, :string
  attribute :starts_on, :date

  relationship :basemap, Basemap

  @moduledoc """
  A trip: a name, the days it runs, and the basemap its stops are drawn on.

  Membership is the framework's role grants rather than a table this app writes. Whoever
  creates a trip is its organizer, granted by the declaration below rather than by any code
  remembering to do it - `granted_to: :creator` is what makes that automatic and what makes
  it impossible to forget.

  An organizer is a member too, so every rule written for members reaches organizers without
  being written twice. That is what `extends:` buys, and it is why deleting and changing who
  is here are the only things the two roles differ on.

  `allow :read_roles` is what lets a member see who else is here. Left undeclared it would
  default to the roles that may change the list - organizers - and a member opening the
  members list would find only themselves in it.

  `allow :grant_role` and `allow :revoke_role` name no role, which means the derived one:
  a holder may hand out or take back their own role and anything it extends, and nothing
  above it. So an organizer may make somebody a member or an organizer, and a member may do
  neither - without this file having to say so twice.

  Anyone may start one, and that is what makes starting one work offline. A create is a
  client write like any other - it lands in the browser's own database first and travels
  afterwards - so `allow :create` is what lets a person begin a trip on a plane. Proven,
  not assumed: with the write held so the server never sees it, the new trip is on screen
  and readable by its creator immediately.
  The organizer grant that `granted_to: :creator` promises is written by the SERVER, in the
  same transaction as the row, when the write lands. The creator sees their trip before
  that grant exists, which is the client trusting its own pending write rather than a hole -
  and it is why nothing here needs a command.
  """

  role :member
  role :organizer, extends: :member, granted_to: :creator

  allow :create
  allow :delete, to: :organizer
  allow :grant_role, to: :organizer
  allow :read, to: :member
  allow :read_roles, to: :member
  allow :revoke_role, to: :organizer
  allow :update, to: :member
end
