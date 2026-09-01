defmodule Offgrid.Pages.TripsPage do
  use Hologram.Page

  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripsList

  @moduledoc """
  The screen a person lands on after signing in: the trips they are on, and the way to
  start another.

  The card sits over the same terrain every other screen uses. The map behind it belongs to
  no trip in particular here - it is the app's backdrop rather than anybody's itinerary,
  which is the one place in the app where that is true.
  """

  route "/trips"

  layout Offgrid.DefaultLayout

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <div class="card wide">
          <h2>Your trips</h2>
          <p class="sub">Everything you are on, wherever you left it.</p>

          <TripsList cid="trips_list" />

          <button class="btn" type="button">New trip</button>
        </div>
      </div>
    </div>
    """
  end
end
