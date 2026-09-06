defmodule Offgrid.Entities.StopTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.Stop, only: [new: 1]

  alias Hologram.Entity
  alias Offgrid.Entities.Stop

  @trip_id "01a05d38-ffc6-7db6-8bc1-152cf7dca119"

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

  describe "__policies__/0" do
    # The rules the entity ends up with are the policy's four, exactly as they were when they
    # were written here - taking a policy on changes where a rule is said, not what it says.
    test "carries the trip members' rules, taken from the policy" do
      assert Stop.__policies__() == [
               {:create, {:trip, :member}, nil, []},
               {:delete, {:trip, :member}, nil, []},
               {:read, {:trip, :member}, nil, []},
               {:update, {:trip, :member}, nil, []}
             ]
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
