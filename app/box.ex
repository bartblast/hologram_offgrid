defmodule Offgrid.Box do
  @moduledoc """
  Where an element sits on screen and how big it is, asked of the DOM.

  A pointer event says where it landed inside an element and nothing about the element, so a
  projection from the screen to the map needs the element's size from the browser. Answers only
  inside a client action, since interop is a no-op on the server.
  """

  use Hologram.JS

  @doc """
  Returns where the element with the given id sits in the window and how big it is, as
  `{left, top, width, height}`.

  For a drag, which starts on a pin and carries on wherever the pointer goes. Offsets measured
  against whatever the pointer is over are no use then, so the drag compares the pointer's
  `client_x` and `client_y` with this.
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
