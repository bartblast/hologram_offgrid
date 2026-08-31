defmodule Offgrid.Entities.StopTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.Stop, only: [new: 1]

  alias Hologram.Entity
  alias Offgrid.Entities.Stop

  describe "Entity.validate/1" do
    test "accepts a complete stop" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan", time: ~T[11:00:00])

      assert Entity.validate(stop) == :ok
    end

    test "refuses a missing name" do
      stop = new(date: ~D[2026-03-30])

      assert Entity.validate(stop) == {:error, %{name: [:required]}}
    end

    test "refuses a time that is not a time" do
      stop = new(date: ~D[2026-03-30], name: "Ryokan", time: "11:00")

      assert Entity.validate(stop) == {:error, %{time: [{:type, :time}]}}
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
