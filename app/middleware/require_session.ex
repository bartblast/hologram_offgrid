defmodule Offgrid.Middleware.RequireSession do
  use Hologram.Middleware

  alias Offgrid.Pages.LogInPage

  @moduledoc """
  Sends anybody without a session to the log-in card.

  Middleware rather than a check inside each page, because this answers BEFORE a page renders:
  no template, no queries, no page bundle for a screen the visitor was never going to see.

  It is not what protects the data - the entity rules are, and they answer the same whether
  this runs or not. What it protects is the experience of arriving somewhere that would have
  had nothing on it.
  """

  @impl Hologram.Middleware
  def call(server, _opts) do
    if server.user_id do
      server
    else
      put_redirect(server, LogInPage)
    end
  end
end
