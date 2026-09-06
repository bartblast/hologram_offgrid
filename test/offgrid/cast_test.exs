defmodule Offgrid.CastTest do
  use ExUnit.Case, async: true

  import Offgrid.Cast

  @bart "01a05d36-4826-77cc-b885-6bb4a30a5ba5"
  @anna "01a05d38-ffc6-7db6-8bc1-152cf7dca119"
  @tom "01a05d99-76cf-73b7-bf0e-4045ea59b4f1"
  @mira "01a05da1-1b2c-7d3e-8f40-5161728394a5"

  # Bart made the trip, then Anna, Tom and Mira joined, in that order.
  @members [@bart, @anna, @tom, @mira]

  describe "colour/3" do
    test "you are always your own colour" do
      assert colour(@members, @tom, @tom) == "y"
    end

    test "the first other member is violet and the second teal" do
      assert colour(@members, @bart, @anna) == "a"
      assert colour(@members, @bart, @tom) == "t"
    end

    test "anyone after the second is grey" do
      assert colour(@members, @bart, @mira) == ""
    end

    test "skips you when counting the others" do
      # On Anna's screen Bart is first and Tom second - Anna herself is not in the count.
      assert colour(@members, @anna, @bart) == "a"
      assert colour(@members, @anna, @tom) == "t"
      assert colour(@members, @anna, @mira) == ""
    end

    test "somebody not on the trip is grey" do
      assert colour(@members, @bart, "01a05db0-0000-7000-8000-000000000000") == ""
    end

    test "with nobody signed in everyone is somebody else" do
      assert colour(@members, nil, @bart) == "a"
      assert colour(@members, nil, @anna) == "t"
    end
  end

  describe "initials/1" do
    test "takes the first letter of the first two words" do
      assert initials("Nora Vale") == "NV"
    end

    test "takes one letter from a one-word name" do
      assert initials("Bart") == "B"
    end

    test "ignores a third word and extra spaces" do
      assert initials("  Anna  Maria Kim ") == "AM"
    end
  end

  describe "members/1" do
    test "names each person once, in the order of their first grant" do
      grants = [
        %{user_id: @bart, role: :organizer},
        %{user_id: @anna, role: :member},
        %{user_id: @bart, role: :member}
      ]

      assert members(grants) == [@bart, @anna]
    end
  end
end
