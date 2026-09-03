defmodule Offgrid.Pages.TripPage do
  use Hologram.Page
  use Hologram.DB

  alias Offgrid.Components.StopEditor
  alias Offgrid.Components.StopsList
  alias Offgrid.Box
  alias Offgrid.Components.MapPicker
  alias Offgrid.Components.MapPins
  alias Offgrid.Components.MapRoute
  alias Offgrid.Components.MembersList
  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripDetails
  alias Offgrid.Components.TripHeader
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Geo
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage

  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  The stops, their pins and the route between them come from the database. The faces are
  still hardcoded - phase G replaces them, without changing the shape of the screen.
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
    |> put_state(:box, nil)
    |> put_state(:details_open, false)
    |> put_state(:drawing, false)
    |> put_state(:maps_open, false)
    |> put_state(:members_open, false)
    |> put_state(:open_stop_id, nil)
    |> put_state(:placing, false)
    |> put_state(:stroke, [])
    |> put_state(:stroke_box, nil)
    |> put_state(:trip_id, params.id)
    |> put_state(:user_id, server.user_id)
    |> put_state(:you, initials(server.user_id))
    # Queued here and run on the client the moment the page is up, after its first render -
    # the framework's answer to "on mount", and the only way a page learns how big it is.
    |> put_action(:measure)
  end

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain trip_id={@trip_id} />

        <!-- The surface a click lands on, laid over the terrain rather than wrapped around it: a
             click whose target sits inside a child component does not reach a listener on the
             element around it, so the surface is a plain element with nothing inside. -->
        <div id="canvas" class={canvas_class(@placing)} $click="place_stop"></div>

        <MapRoute cid="map_route" trip_id={@trip_id} />

        <div
          class={ink_class(@drawing)}
          $pointer_down="ink_start"
          $pointer_move="ink_extend"
          $pointer_up="ink_finish"
        ></div>

        <svg class="ink-paper" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
          {%if @stroke != []}
            <polyline
              class="ink-mine"
              points={stroke_points(@stroke)}
              fill="none"
              vector-effect="non-scaling-stroke"
            />
          {/if}
        </svg>

        <MapPins cid="map_pins" open_stop_id={@open_stop_id} trip_id={@trip_id} />

        <div class="lpanel">
          <div class="lp-head">
            <TripHeader cid="trip_header" trip_id={@trip_id} />
            <div class="lp-tools">
              <button class="swatch" type="button" aria-label="Change map" $click="toggle_maps">
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
              <button
                class={addb_class(@placing)}
                type="button"
                aria-label="Add a stop"
                $click="toggle_placing"
              >
                +
              </button>
            </div>
          </div>

          {%if @maps_open}
            <MapPicker cid="map_picker" trip_id={@trip_id} />
          {/if}

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

        <button class={pen_class(@drawing)} type="button" aria-label="Draw" $click="toggle_drawing">✎</button>

        <!-- The canvas only ever resizes with the window, and a window binding is torn down with
             the page, where an observer on the canvas fires once more as the element goes and
             lands on whichever page comes next. -->
        <window $resize="measure" />

        {%if @placing}
          <document $key_down.escape="toggle_placing" />
        {/if}

        {%if @drawing}
          <document $key_down.escape="toggle_drawing" />
        {/if}

        {%if @details_open}
          <document $key_down.escape="close_details" />

          <TripDetails cid="trip_details" trip_id={@trip_id} user_id={@user_id} />
        {/if}

        {%if @open_stop_id}
          <document $key_down.escape="close_stop" />

          <StopEditor cid="stop_editor" stop_id={@open_stop_id} user_id={@user_id} />
        {/if}
      </div>
    </div>
    """
  end

  # Deleting closes in the SAME action, not through a follow-up: the editor renders the
  # row being deleted, so if it were still mounted for one render in between it would ask
  # the database for a row that is gone.
  def action(:delete_stop, params, component) do
    :ok = DB.delete(Stop, params.id)

    put_state(component, :open_stop_id, nil)
  end

  def action(:close_details, _params, component) do
    put_state(component, :details_open, false)
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

  # A stroke is kept in screen space while it is being drawn - hundredths of the map's width
  # and height - so a move costs one division and nothing else. It becomes real coordinates
  # when it is saved, which is the only moment the map's bounds matter.
  def action(:ink_extend, params, component) do
    if component.state.stroke_box do
      put_state(component, :stroke, [ink_point(component, params.event) | component.state.stroke])
    else
      component
    end
  end

  # Lifting the pointer ends the stroke and leaves it on screen. It is drawn and nowhere else
  # yet - G6 is what turns it into a row - so putting the pen away is what discards it.
  def action(:ink_finish, _params, component) do
    put_state(component, :stroke_box, nil)
  end

  # The box is read from the DOM once, when the pointer goes down, and held for the length of
  # the stroke: every move after it is arithmetic, with nothing asked of the browser.
  #
  # Whether the pen is armed is checked here and not left to the layer's `pointer-events`,
  # which only decides what the pointer HITS - it is the app's rule, so the app states it.
  def action(:ink_start, params, component) do
    if component.state.drawing do
      started = put_state(component, :stroke_box, Box.size("canvas"))

      put_state(started, :stroke, [ink_point(started, params.event)])
    else
      component
    end
  end

  # The one place the app asks the DOM anything. Runs once from init/3, right after the first
  # render, and again on every change of the canvas's size, so the box in state is never the
  # box of a window that has since been resized.
  def action(:measure, _params, component) do
    put_state(component, :box, Box.size("canvas"))
  end

  def action(:open_details, _params, component) do
    put_state(component, :details_open, true)
  end

  def action(:open_stop, params, component) do
    put_state(component, :open_stop_id, params.id)
  end

  # The whole local-first claim in one function: the click becomes a place, the place becomes
  # a row in the client's own database, and the itinerary, the pin and the editor all read that
  # row in the same frame. Only then does any of it travel. Nothing here waits for the server.
  # A click on the map means nothing until the + has armed it.
  def action(:place_stop, params, component) do
    if component.state.placing, do: place(component, params.event), else: component
  end

  def action(:toggle_maps, _params, component) do
    put_state(component, :maps_open, !component.state.maps_open)
  end

  def action(:toggle_members, _params, component) do
    put_state(component, :members_open, !component.state.members_open)
  end

  # The two armed modes are exclusive: the map can be waiting for a place or waiting for ink,
  # and arming either is how you say which.
  def action(:toggle_drawing, _params, component) do
    component
    |> put_state(:drawing, !component.state.drawing)
    |> put_state(:placing, false)
    |> put_state(:stroke, [])
    |> put_state(:stroke_box, nil)
  end

  # + arms placing rather than creating anything, and a second press disarms. Adding a stop
  # means pointing at a place, so the button has exactly one meaning and the map has the other.
  def action(:toggle_placing, _params, component) do
    component
    |> put_state(:drawing, false)
    |> put_state(:placing, !component.state.placing)
  end

  # Only the server can forget an identity - the session cookie it is kept in is the
  # server's to write, which is why this is a command and not an action.
  def command(:log_out, _params, server) do
    server
    |> delete_user_id()
    |> put_action(:logged_out)
  end

  # Pressed while armed, so the button itself says the next click on the map will place.
  defp addb_class(true), do: "addb on"

  defp addb_class(false), do: "addb"

  defp canvas_class(true), do: "canvas placing"

  defp canvas_class(false), do: "canvas"

  defp ink_class(true), do: "ink on"

  defp ink_class(false), do: "ink"

  defp ink_point(component, event) do
    {width, height} = component.state.stroke_box

    {event.offset_x / width * 100, event.offset_y / height * 100}
  end

  defp pen_class(true), do: "pen on"

  defp pen_class(false), do: "pen"

  defp stroke_points(stroke) do
    stroke
    |> Enum.reverse()
    |> Enum.map_join(" ", fn {x, y} -> "#{x},#{y}" end)
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

  defp place(component, event) do
    {width, height} = component.state.box

    trip =
      Trip
      |> filter(id: component.state.trip_id)
      |> include(:basemap)
      |> one()
      |> DB.read()

    {lat, lng} = Geo.from_offset(event.offset_x, event.offset_y, width, height, trip.basemap)

    {:ok, stop} =
      %{date: trip.starts_on, lat: lat, lng: lng, name: "New stop", trip_id: trip.id}
      |> Stop.new()
      |> DB.create()

    component
    |> put_state(:open_stop_id, stop.id)
    |> put_state(:placing, false)
  end
end
