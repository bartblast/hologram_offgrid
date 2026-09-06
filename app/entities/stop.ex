defmodule Offgrid.Entities.Stop do
  use Hologram.Entity

  alias Offgrid.Entities.Trip
  alias Offgrid.Policies.TripMembers

  attribute :date, :date
  attribute :description, :string, optional: true
  attribute :lat, :float, optional: true
  attribute :lng, :float, optional: true
  attribute :name, :string
  attribute :time, :time, optional: true

  # Required, which it could only become once every row already held one - a reference with
  # no value for existing rows is refused, so the column arrived optional, the rows were
  # filled, and only then did it tighten.
  relationship :trip, Trip

  # Whoever is on the trip may do anything to its stops - one sentence, said once, in the
  # policy, and taken on here as if the four lines were written below. The policy explains
  # why it asks about the member role rather than delegating to the trip.
  policy TripMembers
end
