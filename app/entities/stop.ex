defmodule Offgrid.Entities.Stop do
  use Hologram.Entity

  alias Offgrid.Entities.Trip

  attribute :date, :date
  attribute :description, :string, optional: true
  attribute :lat, :float, optional: true
  attribute :lng, :float, optional: true
  attribute :name, :string
  attribute :time, :time, optional: true

  # Optional only while the rows that predate the column catch up. A stop with no trip is
  # meaningless, so this tightens as soon as every row has one - a required reference cannot
  # be added beside rows that lack a value, which is why the two land in that order.
  relationship :trip, Trip, optional: true

  # TODO: replace with membership-scoped rules once stops belong to a trip.
  allow :create
  allow :delete
  allow :read
  allow :update
end
