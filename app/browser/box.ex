defmodule Offgrid.Browser.Box do
  @moduledoc """
  Where an element sits on screen and how big it is, asked of the DOM.

  A pointer event says where it landed and nothing about the element, so turning a pointer
  position into a place on the map needs the element's box from the browser. Answers only
  inside a client action, since interop is a no-op on the server.
  """

  use Hologram.JS

  @doc """
  Returns where the element with the given id sits in the window and how big it is, as
  `{left, top, width, height}`.

  The left and top are what a drag compares the pointer's `client_x` and `client_y` against,
  since a drag carries on wherever the pointer goes. The width and height scale a click's
  `offset_x` and `offset_y` into hundredths of the element.
  """
  @spec rect(String.t()) :: {number, number, number, number}
  def rect(id) do
    box =
      :document
      |> JS.call(:getElementById, [id])
      |> JS.call(:getBoundingClientRect, [])

    {JS.get(box, :left), JS.get(box, :top), JS.get(box, :width), JS.get(box, :height)}
  end
end
