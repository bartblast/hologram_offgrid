defmodule Offgrid.Pages.TripPage do
  use Hologram.Page
  use Hologram.DB

  alias Offgrid.Components.StopEditor
  alias Offgrid.Components.StopsList
  alias Offgrid.Components.MembersList
  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripHeader
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage

  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  The stops come from the database. The pins, the route and the faces are still
  hardcoded - phases F and G replace them in turn, without changing the shape of the
  screen.
  """

  route "/trips/:id"

  param :id, :string

  layout Offgrid.DefaultLayout

  # init/3 runs on the server on every page load, client-side navigations included, so the
  # session's user is readable here and the row it names can be looked up.
  #
  # The trip comes from the address rather than from a lookup. Nothing here checks that the id
  # names a trip this person may see: the queries below it are the check, and they answer with
  # the rows the trip's own rules allow - none, for a trip that is not theirs.
  def init(params, component, server) do
    component
    |> put_state(:members_open, false)
    |> put_state(:open_stop_id, nil)
    |> put_state(:trip_id, params.id)
    |> put_state(:user_id, server.user_id)
    |> put_state(:you, initials(server.user_id))
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
            <TripHeader cid="trip_header" trip_id={@trip_id} />
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

          <StopsList cid="stops_list" open_stop_id={@open_stop_id} trip_id={@trip_id} />
        </div>

        <div class={faces_class(@members_open)}>
          <button
            class="facepile"
            type="button"
            aria-label="Who is on this trip"
            $click="toggle_members"
          >
            <div class="face a">AK</div>
            <div class="face t">TR</div>
            {%if @you}
              <div class="face y">{@you}</div>
            {/if}
          </button>

          {%if @you}
            <span class="sep"></span>
            <button class="signout" type="button" $click="log_out">Log out</button>
          {/if}
        </div>

        {%if @members_open}
          <div class="members">
            <MembersList cid="members_list" trip_id={@trip_id} user_id={@user_id} />
          </div>
        {/if}

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
      %{date: ~D[2026-03-28], name: "New stop", trip_id: component.state.trip_id}
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

  def action(:log_out, _params, component) do
    put_command(component, :log_out)
  end

  def action(:logged_out, _params, component) do
    put_page(component, LogInPage)
  end

  def action(:open_stop, params, component) do
    put_state(component, :open_stop_id, params.id)
  end

  def action(:toggle_members, _params, component) do
    put_state(component, :members_open, !component.state.members_open)
  end

  # Only the server can forget an identity - the session cookie it is kept in is the
  # server's to write, which is why this is a command and not an action.
  def command(:log_out, _params, server) do
    server
    |> delete_user_id()
    |> put_action(:logged_out)
  end

  # The pill takes an accent ring while the panel it opens is up, so the faces read as the
  # control they are rather than as decoration that happened to be clicked.
  defp faces_class(true), do: "faces open"

  defp faces_class(false), do: "faces"

  # Nobody signed in has no face to show, which is a real state until the auth gates land.
  defp initials(nil), do: nil

  defp initials(user_id) do
    user =
      User
      |> filter(id: user_id)
      |> one()
      |> DB.read()

    if user, do: initials_of(user.name)
  end

  # The first letter of each of the first two words, which is what the mockup's faces are.
  defp initials_of(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end
end
