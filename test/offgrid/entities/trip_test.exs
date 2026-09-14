defmodule Offgrid.Entities.TripTest do
  # Not async: the Auth.can?/3 checks empty the database, which other modules write too.
  use ExUnit.Case, async: false

  import Offgrid.Entities.Trip, only: [new: 1]
  import Offgrid.FeatureHelpers, only: [create_trip: 0, create_user: 2, reset_data: 0]

  alias Hologram.Auth
  alias Hologram.Entity
  alias Offgrid.Entities.Trip

  @basemap_id "01a05d37-84be-7b66-b163-1da2ce773bcf"

  describe "Auth.can?/3" do
    # The rules read grants from the database, which only the feature run boots.
    @describetag :feature

    setup do
      reset_data()

      [trip: create_trip(), user: create_user("Nora Vale", "nora@offgrid.test")]
    end

    # A trip can be started by somebody on no trip at all, offline, with no command to ask.
    test "lets anyone create a trip", %{trip: trip, user: user} do
      new_trip =
        new(
          basemap_id: trip.basemap_id,
          ends_on: ~D[2026-05-17],
          name: "Warsaw, long weekend",
          starts_on: ~D[2026-05-15]
        )

      assert Auth.can?(user, :create, new_trip)
    end

    test "lets a member read and update the trip, but not delete it or change who is on it",
         %{trip: trip, user: user} do
      :ok = Auth.grant_role(user, trip, :member)

      assert Auth.can?(user, :read, trip)
      assert Auth.can?(user, :update, trip)
      refute Auth.can?(user, :delete, trip)
      refute Auth.can?(user, :grant_role, trip)
    end

    # The organizer extends the member, so every member rule reaches an organizer without being
    # written twice.
    test "lets an organizer delete the trip and change who is on it", %{trip: trip, user: user} do
      :ok = Auth.grant_role(user, trip, :organizer)

      assert Auth.can?(user, :read, trip)
      assert Auth.can?(user, :update, trip)
      assert Auth.can?(user, :delete, trip)
      assert Auth.can?(user, :grant_role, trip)
    end
  end

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
