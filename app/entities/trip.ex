defmodule Offgrid.Entities.Trip do
  use Hologram.Entity

  alias Offgrid.Entities.Basemap

  attribute :ends_on, :date
  attribute :name, :string
  attribute :starts_on, :date

  relationship :map, Basemap

  @moduledoc """
  A trip: a name, the days it runs, and the map its stops are drawn on.

  Membership is the framework's role grants rather than a table this app writes. Whoever
  creates a trip is its organizer, granted by the declaration below rather than by any code
  remembering to do it - `granted_to: :creator` is what makes that automatic and what makes
  it impossible to forget.

  An organizer is a member too, so every rule written for members reaches organizers without
  being written twice. That is what `extends:` buys, and it is why deleting is the only thing
  the two roles differ on here.

  Nothing grants create. Who may start a trip is a question the page that starts one has to
  answer, and it is answered there rather than here.
  """

  role :member
  role :organizer, extends: :member, granted_to: :creator

  allow :delete, to: :organizer
  allow :manage_roles, to: :organizer
  allow :read, to: :member
  allow :update, to: :member
end
