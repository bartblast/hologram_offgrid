defmodule Offgrid.Pages.TripsPage do
  @moduledoc """
  The screen a person lands on after signing in: the trips they are on, and the way to start
  another.
  """

  use Hologram.Page

  alias Hologram.UI.Link
  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripsList
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.NewTripPage

  route "/trips"

  layout Offgrid.DefaultLayout

  middleware Offgrid.Middleware.RequireSession

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <div class="card wide">
          <h2>Your trips</h2>
          <p class="sub">Everything you are on, wherever you left it.</p>

          <TripsList cid="trips_list" />

          <Link class="btn" to={NewTripPage}>New trip</Link>

          <p class="alt"><button class="signout" type="button" $click="log_out">Log out</button></p>
        </div>
      </div>
    </div>
    """
  end

  def action(:log_out, _params, component) do
    put_command(component, :log_out)
  end

  def action(:logged_out, _params, component) do
    put_page(component, LogInPage)
  end

  # A command, because only the server can write the session.
  def command(:log_out, _params, server) do
    server
    |> delete_user_id()
    |> put_action(:logged_out)
  end
end
