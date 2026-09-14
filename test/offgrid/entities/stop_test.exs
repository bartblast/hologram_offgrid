defmodule Offgrid.Entities.StopTest do
  # Not async: the Auth.can?/3 checks empty the database, which other modules write too.
  use ExUnit.Case, async: false

  import Offgrid.Entities.Stop, only: [new: 1]
  import Offgrid.FeatureHelpers, only: [create_trip: 0, create_user: 2, reset_data: 0]

  alias Hologram.Auth
  alias Hologram.Entity
  alias Offgrid.Entities.Stop

  @trip_id "01a05d38-ffc6-7db6-8bc1-152cf7dca119"

  describe "Auth.can?/3" do
    # The rules read grants from the database, which only the feature run boots.
    @describetag :feature

    setup do
      reset_data()

      [trip: create_trip(), user: create_user("Nora Vale", "nora@offgrid.test")]
    end

    test "lets a member do anything to a stop on their trip", %{trip: trip, user: user} do
      :ok = Auth.grant_role(user, trip, :member)

      stop = new(date: ~D[2026-03-30], name: "Ryokan", trip_id: trip.id)

      assert Auth.can?(user, :create, stop)
      assert Auth.can?(user, :read, stop)
      assert Auth.can?(user, :update, stop)
      assert Auth.can?(user, :delete, stop)
    end

    test "refuses somebody with no role on the trip", %{trip: trip, user: user} do
      stop = new(date: ~D[2026-03-30], name: "Ryokan", trip_id: trip.id)

      refute Auth.can?(user, :create, stop)
    end

    # An organizer's role extends the member's, so the member rules reach organizers too.
    test "lets an organizer do anything to a stop on their trip", %{trip: trip, user: user} do
      :ok = Auth.grant_role(user, trip, :organizer)

      stop = new(date: ~D[2026-03-30], name: "Ryokan", trip_id: trip.id)

      assert Auth.can?(user, :create, stop)
      assert Auth.can?(user, :read, stop)
      assert Auth.can?(user, :update, stop)
      assert Auth.can?(user, :delete, stop)
    end
  end

  describe "Entity.validate/1" do
    test "accepts a complete stop" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan", time: ~T[11:00:00], trip_id: @trip_id)

      assert Entity.validate(stop) == :ok
    end

    test "refuses a missing name" do
      stop = new(date: ~D[2026-03-30], trip_id: @trip_id)

      assert Entity.validate(stop) == {:error, %{name: [:required]}}
    end

    test "refuses a time that is not a time" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan", time: "11:00", trip_id: @trip_id)

      assert Entity.validate(stop) == {:error, %{time: [{:type, :time}]}}
    end

    test "refuses a stop with no trip" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan")

      assert Entity.validate(stop) == {:error, %{trip_id: [:required]}}
    end
  end

  describe "new/1" do
    test "applies defaults to absent optional attributes" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan")

      assert %Stop{
               date: ~D[2026-03-30],
               description: nil,
               lat: nil,
               lng: nil,
               name: "Ryokan",
               time: nil,
               created_at: nil,
               updated_at: nil
             } = stop

      assert is_binary(stop.id)
    end

    test "holds a time of day" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan", time: ~T[11:00:00])

      assert stop.time == ~T[11:00:00]
    end
  end
end
