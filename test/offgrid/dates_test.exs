defmodule Offgrid.DatesTest do
  use ExUnit.Case, async: true

  import Offgrid.Dates

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
