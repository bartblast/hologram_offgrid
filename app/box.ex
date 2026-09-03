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
