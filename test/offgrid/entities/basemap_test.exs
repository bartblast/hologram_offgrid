defmodule Offgrid.Entities.BasemapTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.Basemap,
    only: [from_offset: 5, placed?: 2, to_percent: 3, view_box: 1, within?: 3]

  alias Offgrid.Entities.Basemap

  # The seeded Japan basemap, which is the one every other test draws on.
  @japan %Basemap{max_lat: 45.6, max_lng: 146.0, min_lat: 30.9, min_lng: 128.4}

  describe "from_offset/5" do
    test "reads the top left corner as the north-west corner" do
      assert from_offset(@japan, 0, 0, 900, 520) == {45.6, 128.4}
    end

    test "reads the bottom right corner as the south-east corner" do
      assert from_offset(@japan, 900, 520, 900, 520) == {30.9, 146.0}
    end

    test "reads the middle of the box as the middle of the bounds" do
      {lat, lng} = from_offset(@japan, 450, 260, 900, 520)

      assert Float.round(lat, 4) == 38.25
      assert Float.round(lng, 4) == 137.2
    end

    test "comes back to the place it started from" do
      {x, y} = to_percent(@japan, 35.0116, 135.7681)
      {lat, lng} = from_offset(@japan, x / 100 * 900, y / 100 * 520, 900, 520)

      assert Float.round(lat, 4) == 35.0116
      assert Float.round(lng, 4) == 135.7681
    end
  end

  describe "placed?/2" do
    test "admits a stop with a place on the map" do
      assert placed?(@japan, %{lat: 35.0116, lng: 135.7681})
    end

    test "refuses a stop with no place yet" do
      refute placed?(@japan, %{lat: nil, lng: nil})
    end

    test "refuses a stop whose place is off this map" do
      refute placed?(@japan, %{lat: 52.23, lng: 21.01})
    end
  end

  describe "to_percent/3" do
    test "puts the north-west corner at the top left" do
      assert to_percent(@japan, 45.6, 128.4) == {0.0, 0.0}
    end

    test "puts the south-east corner at the bottom right" do
      assert to_percent(@japan, 30.9, 146.0) == {100.0, 100.0}
    end

    test "puts the middle of the bounds in the middle" do
      {x, y} = to_percent(@japan, 38.25, 137.2)

      # Rounded, because the halfway longitude is not exact in binary and lands a hair short.
      assert Float.round(x, 4) == 50.0
      assert Float.round(y, 4) == 50.0
    end

    test "reads a real place off the map" do
      # Kyoto, which is south of the middle and west of it.
      {x, y} = to_percent(@japan, 35.0116, 135.7681)

      assert Float.round(x, 2) == 41.86
      assert Float.round(y, 2) == 72.03
    end

    test "answers past the edge for a place outside the bounds" do
      {x, y} = to_percent(@japan, 50.0, 120.0)

      assert x < 0
      assert y < 0
    end
  end

  describe "view_box/1" do
    test "spans the basemap in its own units, with latitude negated" do
      # Bounds whose differences are exact in binary, so the string is not a float's last digits.
      basemap = %Basemap{max_lat: 45.5, max_lng: 146.0, min_lat: 31.0, min_lng: 128.0}

      assert view_box(basemap) == "128.0 -45.5 18.0 14.5"
    end
  end

  describe "within?/3" do
    test "admits a place inside the bounds" do
      assert within?(@japan, 35.0116, 135.7681)
    end

    test "admits a place exactly on a corner" do
      assert within?(@japan, 45.6, 128.4)
    end

    test "refuses a place north of the bounds" do
      refute within?(@japan, 50.0, 135.7681)
    end

    test "refuses a place west of the bounds" do
      # Warsaw, which is on another of the app's maps entirely.
      refute within?(@japan, 52.23, 21.01)
    end
  end
end
