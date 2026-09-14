defmodule Offgrid.Stroke do
  @moduledoc """
  The SVG path of a freehand line drawn through a run of points.

  A pointer reports its place a few dozen times a second, so joining the samples with straight
  segments draws the sampling rather than the gesture. Instead, each point becomes the control
  of a quadratic curve that ends at the midpoint between it and the next point, which costs one
  division per point. The line ends with a straight run to the last point.

  Only the first curve names its control. Every later one is a `T`, which reflects the previous
  control about the previous endpoint, and that reflection lands exactly on the next sample. It
  is the same curve, written with two numbers per point instead of four.

  Coordinates are in the caller's units: the trip page passes hundredths of the map for the
  stroke being drawn, and `{lng, -lat}` for the path a sketch is saved with.
  """

  @typedoc "A place on the drawing, in the caller's own units."
  @type point :: {number, number}

  @doc """
  Returns the `d` of an SVG path through the points, curved.

  No points answer the empty string, and a single point answers a move with no line. Both
  render as nothing.
  """
  @spec path(list(point)) :: String.t()
  def path([]), do: ""

  def path([point]), do: "M#{spell(point)}"

  def path([first | rest]) do
    "M#{spell(first)} " <> segments(rest, true)
  end

  # Walked rather than chunked, because chunk_every would allocate a list of pairs the size of
  # the stroke, and the stroke being drawn is re-spelled on every render.
  defp segments([last], _first?), do: "L#{spell(last)}"

  defp segments([{cx, cy} = control, {nx, ny} = next | rest], first?) do
    midpoint = {(cx + nx) / 2, (cy + ny) / 2}

    lead(control, midpoint, first?) <> " " <> segments([next | rest], false)
  end

  defp lead(control, midpoint, true), do: "Q#{spell(control)} #{spell(midpoint)}"

  defp lead(_control, midpoint, false), do: "T#{spell(midpoint)}"

  defp spell({x, y}), do: "#{x},#{y}"
end
