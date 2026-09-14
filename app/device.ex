defmodule Offgrid.Device do
  @moduledoc """
  What only the user's device knows: where an element sits on screen, the clock's time zone,
  and whether there is a network.

  Every function asks through JS interop, so each answers only inside a client action.
  Interop is a no-op on the server.
  """

  use Hologram.JS

  @doc """
  Returns true when the browser reports a network connection, from `navigator.onLine`.

  A command that cannot reach the server raises, and a gesture such as a cursor position or a
  ping is not worth an error, so the page asks here before sending one. It assumes a browser
  with a network can reach the server.
  """
  @spec online?() :: boolean
  def online? do
    JS.get(:navigator, :onLine)
  end

  @doc """
  Returns where the element with the given id sits in the window and how big it is, as
  `{left, top, width, height}`.

  A pointer event says where it landed and nothing about the element, so turning a pointer
  position into a place on the map needs the element's box. The left and top are what a drag
  compares the pointer's `client_x` and `client_y` against, since a drag carries on wherever
  the pointer goes. The width and height scale a click's `offset_x` and `offset_y` into
  hundredths of the element.
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
  Returns how many minutes the device's clock is BEHIND UTC, which is how JavaScript spells
  it: Warsaw in summer answers -120, New York in winter 300, London in winter 0. Remark
  timestamps are stored in UTC and shown in local time with it.

  Truncated, because the arithmetic downstream wants an integer.
  """
  @spec utc_offset_minutes() :: integer
  def utc_offset_minutes do
    :Date
    |> JS.new([])
    |> JS.call(:getTimezoneOffset, [])
    |> trunc()
  end
end
