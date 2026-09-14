defmodule Offgrid.Pages.HomePage do
  @moduledoc """
  The root, which renders nothing: somebody with a session is redirected to their trips, and
  anybody else to the log-in card.

  The redirect is middleware rather than `init/3`, so it happens before anything renders.
  """

  use Hologram.Page

  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripsPage

  route "/"

  layout Offgrid.Components.DefaultLayout

  middleware :doorway

  def doorway(server, _opts) do
    put_redirect(server, landing(server.user_id))
  end

  def template do
    ~HOLO""
  end

  defp landing(nil), do: LogInPage

  defp landing(_user_id), do: TripsPage
end
