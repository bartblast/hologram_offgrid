defmodule Offgrid.DatesTest do
  use ExUnit.Case, async: true

  import Offgrid.Dates

  describe "day_label/1" do
    test "spells the weekday, the day and the month" do
      assert day_label(~D[2026-03-28]) == "Sat 28 Mar"
    end

    test "does not pad a single-digit day" do
      assert day_label(~D[2026-04-06]) == "Mon 6 Apr"
    end
  end

  describe "month/1" do
    test "names the first and the last month" do
      assert month(1) == "Jan"
      assert month(12) == "Dec"
    end
  end

  describe "pad/1" do
    test "pads below ten and leaves the rest alone" do
      assert pad(5) == "05"
      assert pad(10) == "10"
      assert pad(0) == "00"
    end
  end

  describe "parse/1" do
    test "reads what a date input spells" do
      assert parse("2026-05-15") == ~D[2026-05-15]
    end

    test "answers nil for a date the input has not finished spelling" do
      assert parse("2026-05") == nil
    end

    test "answers nil for an empty field" do
      assert parse("") == nil
    end

    test "answers nil for a day that does not exist" do
      assert parse("2026-13-45") == nil
    end

    test "answers nil for parts that are not numbers" do
      assert parse("abcd-ef-gh") == nil
    end

    test "reads parts that are not padded" do
      assert parse("2026-5-9") == ~D[2026-05-09]
    end
  end

  describe "span/2" do
    test "names the month once when a single month covers the trip" do
      assert span(~D[2026-03-28], ~D[2026-03-30]) == "28 – 30 Mar"
    end

    test "names both months when the trip crosses one" do
      assert span(~D[2026-03-28], ~D[2026-04-06]) == "28 Mar – 6 Apr"
    end

    test "names both months when the trip crosses a year" do
      assert span(~D[2026-12-29], ~D[2027-01-03]) == "29 Dec – 3 Jan"
    end

    test "reads the same for a trip that starts and ends on one day" do
      assert span(~D[2026-05-15], ~D[2026-05-15]) == "15 – 15 May"
    end
  end

  describe "time_label/1" do
    test "pads the hour and the minute" do
      assert time_label(~T[09:05:00]) == "09:05"
    end

    test "reads a time that came back from the database with microseconds" do
      assert time_label(~T[14:20:00.000000]) == "14:20"
    end
  end

  describe "weekday/1" do
    test "names the days at both ends of the week" do
      assert weekday(~D[2026-03-30]) == "Mon"
      assert weekday(~D[2026-04-05]) == "Sun"
    end
  end

  describe "to_input/1" do
    test "pads the month and the day a date input expects two digits of" do
      assert to_input(~D[2026-05-09]) == "2026-05-09"
    end

    test "leaves two-digit parts alone" do
      assert to_input(~D[2026-12-25]) == "2026-12-25"
    end

    test "answers the empty string for no date" do
      assert to_input(nil) == ""
    end
  end
end
