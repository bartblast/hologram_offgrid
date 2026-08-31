defmodule Offgrid.Entities.Stop do
  use Hologram.Entity

  attribute :date, :date
  attribute :description, :string, optional: true
  attribute :lat, :float, optional: true
  attribute :lng, :float, optional: true
  attribute :name, :string
  attribute :time, :time, optional: true

  # TODO: replace with membership-scoped rules once stops belong to a trip.
  allow :create
  allow :delete
  allow :read
  allow :update
end
