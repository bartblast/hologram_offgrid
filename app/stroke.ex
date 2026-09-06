defmodule Offgrid.Stroke do
  @moduledoc """
  The shape of a freehand line drawn through a run of points.

  A pointer reports its place a few dozen times a second and the places between are the
  hand's, not the browser's - so joining them with straight segments draws the sampling rather
  than the gesture, and a quick flick comes out as a row of facets. This turns the points into
  a curve instead.

  The method is the cheap one and the right one here: every point becomes the control of a
  quadratic curve whose ends are the midpoints of its neighbours. The line then passes through
  each midpoint and bends towards each sample, which is what a hand does, and it costs one
  division per point - no fitting, no lookahead, nothing to tune. The first and last points are
  joined straight, because a curve needs a neighbour on both sides and the ends have one.

  Only the first curve names its control. Every one after it is a `T`, which continues the
  quadratic by reflecting the previous control about the previous endpoint - and that
  reflection lands exactly on the next sample, which is the control this method wanted anyway.
  So it is the SAME curve written with two numbers per point instead of four. That halves the
  number-to-string conversions, which is what this costs: measured at about 106 microseconds a
  point before, against 47 for parsing and projecting the same point.

  Coordinates are whatever the caller is drawing in. The page hands it hundredths of the map
  while a stroke is being made and `Ink` hands it the same hundredths projected back from the
  real coordinates a sketch is stored in, so one function serves both.
  """

  @typedoc "A place on the drawing, in the caller's own units."
  @type point :: {number, number}

  @doc """
  Returns the `d` of an SVG path through the points, curved.

  Nothing to draw answers the empty string, and a single point answers a move with no line -
  both render as nothing, which is what a stroke that has not started yet should look like.
  """
  @spec path(list(point)) :: String.t()
  def path([]), do: ""

  def path([point]), do: "M#{spell(point)}"

  def path([first | rest]) do
    "M#{spell(first)} " <> segments(rest, true)
  end

  # Walked rather than chunked: chunk_every allocates a list of pairs the size of the stroke,
  # and this runs for every sketch on every render.
  defp segments([last], _first?), do: "L#{spell(last)}"

  defp segments([{cx, cy} = control, {nx, ny} = next | rest], first?) do
    midpoint = {(cx + nx) / 2, (cy + ny) / 2}

    lead(control, midpoint, first?) <> " " <> segments([next | rest], false)
  end

  defp lead(control, midpoint, true), do: "Q#{spell(control)} #{spell(midpoint)}"

  defp lead(_control, midpoint, false), do: "T#{spell(midpoint)}"

  defp spell({x, y}), do: "#{x},#{y}"
end
