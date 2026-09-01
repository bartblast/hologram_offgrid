defmodule Offgrid.Entities.Stop do
  use Hologram.Entity

  alias Offgrid.Entities.Trip

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

  # One sentence, four times: whoever is on the trip may do anything to its stops.
  #
  # `to: {:trip, :member}` asks whether the actor holds :member on the row this stop's trip
  # reference names - per row, so a member of another trip gets nothing. The alternative,
  # `via: :trip`, delegates the SAME operation to the trip, and that only tells the truth
  # here for read and update: nothing grants :create on a Trip, and its :delete is
  # organizers only, so creating a stop would refuse everyone and deleting one would refuse
  # every member.
  allow :create, to: {:trip, :member}
  allow :delete, to: {:trip, :member}
  allow :read, to: {:trip, :member}
  allow :update, to: {:trip, :member}
end
