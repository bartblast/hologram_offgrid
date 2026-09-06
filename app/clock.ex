defmodule Offgrid.Clock do
  use Hologram.JS

  @moduledoc """
  What time zone the browser is in, asked of the browser.

  A remark's timestamp is stored in UTC and nothing on the server knows where the person
  reading it is sitting. The browser does, and this is the app's single place that asks it -
  the framework's door to JavaScript kept behind a facade, like `Offgrid.Box`, so the rest
  of the app reads a number rather than a `Date` object.

  Answers only inside an action on the client, which is where interop runs. On the server it
  is a no-op, and nothing on the server has a reason to ask.
  """

  @doc """
  Returns how many minutes the browser's clock is BEHIND UTC, which is how JavaScript spells
  it: Warsaw in summer answers -120, New York in winter 300, London in winter 0.

  Truncated, because a JavaScript number comes back as whatever it is and the arithmetic
  downstream wants an integer.
  """
  @spec offset_minutes() :: integer
  def offset_minutes do
    :Date
    |> JS.new([])
    |> JS.call(:getTimezoneOffset, [])
    |> trunc()
  end
end
