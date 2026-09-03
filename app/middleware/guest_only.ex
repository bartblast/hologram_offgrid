defmodule Offgrid.Middleware.GuestOnly do
  use Hologram.Middleware

  alias Offgrid.Pages.TripsPage

  @moduledoc """
  Sends anybody who is already signed in away from the cards for signing in.

  The mirror of `RequireSession`, and the reason the pair exists rather than one gate: a person
  with a session has no business on the log-in card, and one without has none on a trip.
  """

  @impl Hologram.Middleware
  def call(server, _opts) do
    if server.user_id do
      put_redirect(server, TripsPage)
    else
      server
    end
  end
end
