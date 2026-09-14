defmodule Offgrid.Browser.Network do
  @moduledoc """
  Whether this browser has a network right now.

  A command that cannot reach the server raises, and a gesture such as a cursor position or a
  ping is not worth an error, so the page asks here before sending one. It assumes a browser
  with a network can reach the server. Answers only inside a client action, since interop is a
  no-op on the server.
  """

  use Hologram.JS

  @doc """
  Returns true when the browser reports a network connection, from `navigator.onLine`.
  """
  @spec online?() :: boolean
  def online? do
    JS.get(:navigator, :onLine)
  end
end
