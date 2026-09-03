defmodule Offgrid.Pages.HomePage do
  use Hologram.Page

  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripsPage

  @moduledoc """
  The door at the root: it sends you where you were going and renders nothing of its own.

  Middleware rather than `init/3`, because middleware answers BEFORE anything is rendered -
  no template, no queries, no page bundle - which is what a door should cost. Somebody with a
  session lands on their trips, and anybody else on the log-in card.

  There is no third answer to give. The root belonged to the trip screen while one trip owned
  the app, and now that a trip's address names it, the root has nothing to show.
  """

  route "/"

  layout Offgrid.DefaultLayout

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
