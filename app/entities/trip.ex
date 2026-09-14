defmodule Offgrid.Entities.Trip do
  @moduledoc """
  A trip: a name, the days it runs, and the basemap its stops are drawn on.

  Membership is the framework's role grants rather than a table this app writes. Whoever
  creates a trip becomes its organizer through `granted_to: :creator`, and an organizer is also
  a member through `extends:`, so the roles differ only on deleting the trip and changing who
  is on it.

  `allow :read_roles` lets a member see who else is on the trip. Without it only the roles that
  may change the list, organizers, could see it. `:grant_role` and `:revoke_role` name no role
  to grant, so an organizer may grant or revoke either role.

  Anyone may create a trip, and the create lands in the browser's database first, so a trip can
  be started offline. The server writes the organizer grant in the same transaction as the row
  when the write arrives, so no command is needed.
  """

  use Hologram.Entity

  alias Offgrid.Entities.Basemap

  attribute :ends_on, :date
  attribute :name, :string
  attribute :starts_on, :date

  relationship :basemap, Basemap

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
