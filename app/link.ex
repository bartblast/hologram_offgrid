defmodule Offgrid.Link do
  use Hologram.JS

  @moduledoc """
  Whether this browser has a network right now, asked of the browser.

  A message that is a gesture rather than a record - a cursor position, a ping, a mark on the
  field somebody is typing in - is not worth an error when it cannot be sent, and a command
  that cannot reach the server raises one. So before sending such a message the page asks
  here, and sends nothing while the answer is no. The assumption, stated: a browser with a
  network has a server. A server that is down while the network is up is an outage, which
  the app is not built around.

  Answers only inside an action on the client, which is where interop runs; on the server it
  is a no-op, and nothing on the server has a reason to ask.
  """

  @doc """
  Returns true when the browser reports a network connection - `navigator.onLine`, which
  goes false on a plane and in a tunnel and true again the moment the network is back.
  """
  @spec online?() :: boolean
  def online? do
    JS.get(:navigator, :onLine)
  end
end
