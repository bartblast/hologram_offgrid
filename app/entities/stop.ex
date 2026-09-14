defmodule Offgrid.Entities.Stop do
  @moduledoc """
  A place on a trip's itinerary. Its rules come from `Offgrid.Policies.TripMembers`: whoever is
  on the trip may do anything to its stops.
  """

  use Hologram.Entity

  alias Offgrid.Entities.Trip
  alias Offgrid.Policies.TripMembers

  attribute :date, :date
  attribute :description, :string, optional: true
  attribute :lat, :float, optional: true
  attribute :lng, :float, optional: true
  attribute :name, :string
  attribute :time, :time, optional: true

  relationship :trip, Trip

  policy TripMembers
end
