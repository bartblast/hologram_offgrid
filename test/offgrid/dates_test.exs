defmodule Offgrid.DatesTest do
  use ExUnit.Case, async: true

  import Offgrid.Dates

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
end
