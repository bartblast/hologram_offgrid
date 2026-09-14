defmodule Offgrid.Middleware.GuestOnly do
  @moduledoc """
  Sends anybody who is already signed in away from the log-in and sign-up pages. The mirror of
  `Offgrid.Middleware.RequireSession`.
  """

  use Hologram.Middleware

  alias Offgrid.Pages.TripsPage

  @impl Hologram.Middleware
  def call(server, _opts) do
    if server.user_id do
      put_redirect(server, TripsPage)
    else
      server
    end
  end
end
