defmodule Offgrid.StrokeTest do
  use ExUnit.Case, async: true

  import Offgrid.Stroke

  describe "path/1" do
    test "draws nothing for no points" do
      assert path([]) == ""
    end

    test "moves to a lone point and draws no line" do
      assert path([{10, 20}]) == "M10,20"
    end

    # Two points have no neighbour to bend around, so the honest answer is a straight line.
    test "joins two points straight" do
      assert path([{0, 0}, {10, 10}]) == "M0,0 L10,10"
    end

    # The curve's ends are the midpoints of each pair and its control is the point between, so
    # the line passes between the samples and leans towards each one.
    test "bends a three-point stroke around its middle" do
      assert path([{0, 0}, {10, 0}, {20, 10}]) == "M0,0 Q10,0 15.0,5.0 L20,10"
    end

    # Only the first curve names its control. Each one after continues the quadratic by
    # reflecting the last control about the last endpoint, which lands on the next sample -
    # the very control this method would have written out. Same curve, half the numbers.
    test "names a control once and continues from it" do
      d = path([{0, 0}, {10, 0}, {20, 10}, {30, 10}, {40, 0}])

      assert d == "M0,0 Q10,0 15.0,5.0 T25.0,10.0 T35.0,5.0 L40,0"
    end

    test "carries one curve per interior point" do
      d = path([{0, 0}, {10, 0}, {20, 10}, {30, 10}, {40, 0}])

      assert length(String.split(d, ["Q", "T"])) - 1 == 3
    end

    # Whatever else it does, a stroke starts where the hand went down and ends where it lifted.
    test "starts and ends on the points the hand gave it" do
      d = path([{1, 2}, {5, 9}, {11, 3}, {17, 8}])

      assert String.starts_with?(d, "M1,2 ")
      assert String.ends_with?(d, " L17,8")
    end
  end
end
