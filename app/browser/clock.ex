defmodule Offgrid.Browser.Clock do
  @moduledoc """
  The browser's time zone, so remark timestamps stored in UTC can be shown in local time.
  Answers only inside a client action, since interop is a no-op on the server.
  """

  use Hologram.JS

  @doc """
  Returns how many minutes the browser's clock is BEHIND UTC, which is how JavaScript spells
  it: Warsaw in summer answers -120, New York in winter 300, London in winter 0.

  Truncated, because the arithmetic downstream wants an integer.
  """
  @spec offset_minutes() :: integer
  def offset_minutes do
    :Date
    |> JS.new([])
    |> JS.call(:getTimezoneOffset, [])
    |> trunc()
  end
end
