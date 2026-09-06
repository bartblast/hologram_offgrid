defmodule Offgrid.GeoTest do
  use ExUnit.Case, async: true

  import Offgrid.Geo

  alias Offgrid.Entities.Basemap

  # The seeded Japan basemap, which is the one every other test draws on.
  @japan %Basemap{max_lat: 45.6, max_lng: 146.0, min_lat: 30.9, min_lng: 128.4}

  describe "within?/3" do
    test "admits a place inside the bounds" do
      assert within?(35.0116, 135.7681, @japan)
    end

    test "admits a place exactly on a corner" do
      assert within?(45.6, 128.4, @japan)
    end

    test "refuses a place north of the bounds" do
      refute within?(50.0, 135.7681, @japan)
    end

    test "refuses a place west of the bounds" do
      # Warsaw, which is on another of the app's maps entirely.
      refute within?(52.23, 21.01, @japan)
    end
  end

  describe "placed?/2" do
    test "admits a stop with a place on the map" do
      assert placed?(%{lat: 35.0116, lng: 135.7681}, @japan)
    end

    test "refuses a stop with no place yet" do
      refute placed?(%{lat: nil, lng: nil}, @japan)
    end

    test "refuses a stop whose place is off this map" do
      refute placed?(%{lat: 52.23, lng: 21.01}, @japan)
    end
  end

  describe "to_percent/3" do
    test "puts the north-west corner at the top left" do
      assert to_percent(45.6, 128.4, @japan) == {0.0, 0.0}
    end

    test "puts the south-east corner at the bottom right" do
      assert to_percent(30.9, 146.0, @japan) == {100.0, 100.0}
    end

    test "puts the middle of the bounds in the middle" do
      {x, y} = to_percent(38.25, 137.2, @japan)

      # Rounded, because the halfway longitude is not exact in binary and lands a hair short.
      assert Float.round(x, 4) == 50.0
      assert Float.round(y, 4) == 50.0
    end

    test "reads a real place off the map" do
      # Kyoto, which is south of the middle and west of it.
      {x, y} = to_percent(35.0116, 135.7681, @japan)

      assert Float.round(x, 2) == 41.86
      assert Float.round(y, 2) == 72.03
    end

    test "answers past the edge for a place outside the bounds" do
      {x, y} = to_percent(50.0, 120.0, @japan)

      assert x < 0
      assert y < 0
    end
  end

  describe "from_offset/5" do
    test "reads the top left corner as the north-west corner" do
      assert from_offset(0, 0, 900, 520, @japan) == {45.6, 128.4}
    end

    test "reads the bottom right corner as the south-east corner" do
      assert from_offset(900, 520, 900, 520, @japan) == {30.9, 146.0}
    end

    test "reads the middle of the box as the middle of the bounds" do
      {lat, lng} = from_offset(450, 260, 900, 520, @japan)

      assert Float.round(lat, 4) == 38.25
      assert Float.round(lng, 4) == 137.2
    end

    test "comes back to the place it started from" do
      {x, y} = to_percent(35.0116, 135.7681, @japan)
      {lat, lng} = from_offset(x / 100 * 900, y / 100 * 520, 900, 520, @japan)

      assert Float.round(lat, 4) == 35.0116
      assert Float.round(lng, 4) == 135.7681
    end
  end
end
