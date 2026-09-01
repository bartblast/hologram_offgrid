defmodule Offgrid.Pages.TripPage do
  use Hologram.Page
  use Hologram.DB

  alias Offgrid.Components.StopEditor
  alias Offgrid.Components.StopsList
  alias Offgrid.Components.Terrain
  alias Offgrid.Entities.Stop

  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  The stops come from the database. The pins, the route and the faces are still
  hardcoded - phases F and G replace them in turn, without changing the shape of the
  screen.
  """

  route "/"

  layout Offgrid.DefaultLayout

  def init(_params, component, _server) do
    put_state(component, :open_stop_id, nil)
  end

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
              <button class="addb" type="button" aria-label="Add a stop" $click="add_stop">+</button>
            </div>
          </div>

          <StopsList cid="stops_list" open_stop_id={@open_stop_id} />
        </div>

        <div class="faces">
          <div class="face a">AK</div>
          <div class="face t">TR</div>
          <div class="face y">BB</div>
        </div>

        <button class="pen" type="button" aria-label="Draw">✎</button>

        {%if @open_stop_id}
          <document $key_down.escape="close_stop" />

          <StopEditor cid="stop_editor" stop_id={@open_stop_id} />
        {/if}
      </div>
    </div>
    """
  end

  # The whole local-first claim in one function: the row is written to the client's own
  # database, the list's query sees it in the same frame, and only then does any of it
  # travel. Nothing here waits for the server.
  def action(:add_stop, _params, component) do
    {:ok, stop} =
      %{date: ~D[2026-03-28], name: "New stop"}
      |> Stop.new()
      |> DB.create()

    put_state(component, :open_stop_id, stop.id)
  end

  # Deleting closes in the SAME action, not through a follow-up: the editor renders the
  # row being deleted, so if it were still mounted for one render in between it would ask
  # the database for a row that is gone.
  def action(:delete_stop, params, component) do
    :ok = DB.delete(Stop, params.id)

    put_state(component, :open_stop_id, nil)
  end

  def action(:close_stop, _params, component) do
    put_state(component, :open_stop_id, nil)
  end

  def action(:open_stop, params, component) do
    put_state(component, :open_stop_id, params.id)
  end
end
