defmodule Offgrid.Entities.TripTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.Trip, only: [new: 1]

  alias Hologram.Entity
  alias Offgrid.Entities.Trip

  @basemap_id "01a05d37-84be-7b66-b163-1da2ce773bcf"

  describe "Entity.validate/1" do
    test "accepts a complete trip" do
      trip =
        new(
          ends_on: ~D[2026-04-06],
          basemap_id: @basemap_id,
          name: "Japan, blossom run",
          starts_on: ~D[2026-03-28]
        )

      assert Entity.validate(trip) == :ok
    end

    test "refuses a missing basemap" do
      trip = new(ends_on: ~D[2026-04-06], name: "Japan, blossom run", starts_on: ~D[2026-03-28])

      assert Entity.validate(trip) == {:error, %{basemap_id: [:required]}}
    end

    test "refuses a date that is not a date" do
      trip =
        new(
          ends_on: "2026-04-06",
          basemap_id: @basemap_id,
          name: "Japan, blossom run",
          starts_on: ~D[2026-03-28]
        )

      assert Entity.validate(trip) == {:error, %{ends_on: [{:type, :date}]}}
    end
  end

  describe "__roles__/0" do
    # The organizer extending the member is what lets every member rule reach an organizer
    # without being written twice, and granted_to: :creator is what makes whoever starts a
    # trip its organizer without any code remembering to do it.
    test "declares a member and an organizer who is also a member" do
      assert Trip.__roles__() == [
               member: [],
               organizer: [extends: :member, granted_to: :creator]
             ]
    end
  end

  describe "new/1" do
    test "holds the days the trip runs and the basemap it is drawn on" do
      trip =
        new(
          ends_on: ~D[2026-04-06],
          basemap_id: @basemap_id,
          name: "Japan, blossom run",
          starts_on: ~D[2026-03-28]
        )

      assert %Trip{
               ends_on: ~D[2026-04-06],
               basemap_id: @basemap_id,
               name: "Japan, blossom run",
               starts_on: ~D[2026-03-28],
               created_at: nil,
               updated_at: nil
             } = trip

      assert is_binary(trip.id)
    end
  end
end
