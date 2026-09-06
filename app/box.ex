defmodule Offgrid.Box do
  use Hologram.JS

  @moduledoc """
  The size of an element on screen, asked of the DOM.

  A click carries where it landed inside its element and nothing about the element, so the
  one number a projection is missing is one only the browser has. This is the app's single
  place that asks for it - the framework's own door to JavaScript, kept behind a facade so
  the rest of the app reads a size rather than a DOM.

  Answers only inside an action on the client, which is where interop runs. On the server it
  is a no-op, and nothing on the server has a reason to ask.
  """

  @doc """
  Returns where the element with the given id sits in the window and how big it is, as
  `{left, top, width, height}`.

  For a gesture that outlives the element it started on. A drag begins on a pin and carries
  on wherever the pointer goes, so the offsets a pointer event measures against whatever it
  is over are no use - what serves is the pointer's place in the window, `client_x` and
  `client_y`, against the map's own place in the window, which is this.
  """
  @spec rect(String.t()) :: {number, number, number, number}
  def rect(id) do
    box =
      :document
      |> JS.call(:getElementById, [id])
      |> JS.call(:getBoundingClientRect, [])

    {JS.get(box, :left), JS.get(box, :top), JS.get(box, :width), JS.get(box, :height)}
  end

  @doc """
  Returns the width and height of the element with the given id, as the browser lays it out.

  The padding box (`clientWidth`, `clientHeight`), because that is what a click's `offset_x`
  and `offset_y` are measured against - the two have to agree or a projection lands off by the
  border.
  """
  @spec size(String.t()) :: {number, number}
  def size(id) do
    element = JS.call(:document, :getElementById, [id])

    {JS.get(element, :clientWidth), JS.get(element, :clientHeight)}
  end
end
