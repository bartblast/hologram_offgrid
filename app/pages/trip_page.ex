defmodule Offgrid.Pages.TripPage do
  use Hologram.Page

  alias Offgrid.Components.StopEditor
  alias Offgrid.Components.Terrain

  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  Everything here is still hardcoded - the stops, the days, the pins and the faces. The
  data layer arrives in phase C, which replaces the markup below piece by piece without
  changing the shape of the screen.
  """

  route "/"

  layout Offgrid.DefaultLayout

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <svg class="lay" viewBox="0 0 1200 520" preserveAspectRatio="none" aria-hidden="true">
          <polyline
            class="rt"
            points="492,125 528,104 540,208 684,385"
            fill="none"
            vector-effect="non-scaling-stroke"
          />
        </svg>

        <div class="pin" style="left:41%;top:24%"><i></i><em>Haneda → Shinjuku</em></div>
        <div class="pin" style="left:44%;top:20%"><i></i><em>Coffee at Fuglen</em></div>
        <div class="pin mine" style="left:45%;top:40%"><i></i><em>Ryokan</em></div>
        <div class="pin" style="left:57%;top:74%"><i></i><em>Fushimi Inari</em></div>

        <div class="lpanel">
          <div class="lp-head">
            <div>
              <div class="lp-title">Japan, blossom run</div>
              <div class="lp-dates">28 Mar – 6 Apr</div>
            </div>
            <div class="lp-tools">
              <button class="swatch" type="button" aria-label="Change map">
                <svg viewBox="0 0 90 44" aria-hidden="true">
                  <rect width="90" height="44" fill="var(--land)" />
                  <rect x="8" y="6" width="20" height="13" fill="var(--park)" />
                  <path
                    d="M0 30 C18 26, 34 34, 52 30 C70 26, 82 32, 90 30 L90 38 C80 40, 68 34, 52 38 C34 42, 16 34, 0 38 Z"
                    fill="var(--water)"
                  />
                  <g stroke="var(--road)" stroke-width="2.5" fill="none">
                    <path d="M0 12 H90 M0 24 H90 M22 0 V44 M52 0 V44 M72 0 V26" />
                  </g>
                </svg>
              </button>
              <button class="addb" type="button" aria-label="Add a stop">+</button>
            </div>
          </div>

          <div class="day">Sat 28 Mar</div>
          <div class="stop">
            <h4>Haneda → Shinjuku</h4>
            <p>14:20 arrival</p>
          </div>
          <div class="stop">
            <h4>Coffee at Fuglen</h4>
            <p>Best pour-over in town</p>
          </div>

          <div class="day">Mon 30 Mar</div>
          <div class="stop open">
            <h4>Ryokan</h4>
            <p>11:00 · Two nights, onsen on site</p>
          </div>

          <div class="day">Wed 1 Apr</div>
          <div class="stop">
            <h4>Fushimi Inari</h4>
            <p>06:30 · Before 7am or forget it</p>
          </div>
        </div>

        <div class="faces">
          <div class="face a">AK</div>
          <div class="face t">TR</div>
          <div class="face y">BB</div>
        </div>

        <button class="pen" type="button" aria-label="Draw">✎</button>

        <StopEditor cid="stop_editor" />
      </div>
    </div>
    """
  end
end
