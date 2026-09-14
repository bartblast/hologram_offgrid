defmodule Offgrid.Pages.TripsPage do
  @moduledoc """
  The screen a person lands on after signing in: the trips they are on, and the way to start
  another.
  """

  use Hologram.Page

  alias Hologram.UI.Link
  alias Offgrid.Components.LogOutButton
  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripList
  alias Offgrid.Pages.NewTripPage

  route "/trips"

  layout Offgrid.Components.DefaultLayout

  middleware Offgrid.Middleware.RequireSession

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <div class="card wide">
          <h2>Your trips</h2>
          <p class="sub">Everything you are on, wherever you left it.</p>

          <TripList />

          <Link class="btn" to={NewTripPage}>New trip</Link>

          <p class="alt"><LogOutButton cid="log_out" /></p>
        </div>
      </div>
    </div>
    """
  end
end
