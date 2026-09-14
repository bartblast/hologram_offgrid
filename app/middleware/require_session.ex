defmodule Offgrid.Middleware.RequireSession do
  @moduledoc """
  Sends anybody without a session to the log-in page, before the requested page renders.

  This does not protect the data - the entity rules do that whether this runs or not. It only
  spares a signed-out visitor a page that would have nothing on it.
  """

  use Hologram.Middleware

  alias Offgrid.Pages.LogInPage

  @impl Hologram.Middleware
  def call(server, _opts) do
    if server.user_id do
      server
    else
      put_redirect(server, LogInPage)
    end
  end
end
