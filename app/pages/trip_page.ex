defmodule Offgrid.Pages.TripPage do
  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  Everything drawn here is a row in the browser's own database, except three gestures that are
  not records: the stroke being drawn, the ping, and who is here. The stroke belongs to
  `InkTools`. The ping and who is here live in this page's state and travel as broadcasts on
  the trip's channel, because several components read them and state only flows down.

  The page holds the screen's mode (idle, placing a stop, or drawing) and the ids the panels
  are open on. The map's parts are components: `MapSurface` takes clicks and the pointer,
  `StopsLayer` draws the pins and the route, and `InkTools` handles drawing.
  """

  use Hologram.Page
  use Hologram.DB

  import Offgrid.Classes

  alias Offgrid.Components.Cursors
  alias Offgrid.Components.Faces
  alias Offgrid.Components.InkTools
  alias Offgrid.Components.LogOutButton
  alias Offgrid.Components.MapPicker
  alias Offgrid.Components.MapSurface
  alias Offgrid.Components.MapSwatch
  alias Offgrid.Components.MembersList
  alias Offgrid.Components.StopEditor
  alias Offgrid.Components.StopsLayer
  alias Offgrid.Components.StopsList
  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripDetails
  alias Offgrid.Components.TripHeader
  alias Offgrid.Device
  alias Offgrid.Entities.Stop
  alias Offgrid.Geo
  alias Offgrid.Presence
  alias Offgrid.Queries
  alias Offgrid.TripChannel
  alias Offgrid.Trips

  # How often a browser says it is still here, and how long the others wait before letting it
  # go. The ratio is the safety margin: four beats fit in the window, so two late beats in a row
  # do not drop somebody. Each beat is a render on every other screen, so it cannot be shorter.
  @heartbeat_ms 500
  @forget_after_ms 2_000

  # Somebody else's pointer is dropped when nothing newer has arrived in this long.
  @cursor_expiry_ms 2_500

  # How long the stop panel takes to slide out, which is how long the page keeps the stop it
  # was open on. The stylesheet's `.editor` transition runs for the same time.
  @panel_slide_ms 250

  @ping_ms 3_000

  # A join the server refuses is asked again after a pause, up to this many joins in all.
  @join_attempts 2
  @rejoin_ms 3_000

  route "/trips/:id"

  param :id, :string

  layout Offgrid.Components.DefaultLayout

  middleware Offgrid.Middleware.RequireSession

  # Nothing here checks that the id names a trip this person may see. The queries are the
  # check, and the trip's rules give them no rows for a trip that is not theirs.
  def init(params, component, server) do
    initialized =
      component
      |> put_state(
        cursors: %{},
        details_open: false,
        editing: %{},
        focused_field: nil,
        initials: TripChannel.initials(server.user_id),
        join_tries: 0,
        maps_open: false,
        members_open: false,
        mode: :idle,
        open_stop_id: nil,
        panel_open: false,
        ping: nil,
        present: [],
        presence_seq: 0,
        trip_id: params.id,
        tz_offset: 0,
        user_id: server.user_id
      )
      # Runs on the client after the first render. A component may queue one action, so
      # everything that needs the page on screen shares it.
      |> put_action(:mounted)

    {initialized, server}
  end

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain trip_id={@trip_id} />

        <MapSurface cid="map_surface" placing={@mode == :placing} trip_id={@trip_id} />

        <StopsLayer cid="stops_layer" open_stop_id={@open_stop_id} trip_id={@trip_id} />

        <InkTools
          cid="ink_tools"
          drawing={@mode == :drawing}
          panel_open={@panel_open}
          trip_id={@trip_id}
          user_id={@user_id}
        />

        <Cursors cursors={@cursors} trip_id={@trip_id} user_id={@user_id} />

        {%if @ping}
          <div class="ping" style={"left:#{@ping.x}%;top:#{@ping.y}%"}>
            <i class="wash"></i><i class="edge"></i><b></b>
          </div>
        {/if}

        <div class="lpanel">
          <div class="lp-head">
            <TripHeader trip_id={@trip_id} />
            <div class="lp-tools">
              <MapSwatch trip_id={@trip_id} />
              <button
                class={classes(["addb", on: @mode == :placing])}
                type="button"
                aria-label="Add a stop"
                $click="toggle_placing"
              >
                <svg viewBox="0 0 12 12" aria-hidden="true">
                  <path d="M6 2 V10 M2 6 H10" />
                </svg>
              </button>
            </div>
          </div>

          {%if @maps_open}
            <MapPicker cid="map_picker" trip_id={@trip_id} />
          {/if}

          <StopsList
            cid="stops_list"
            editing={@editing}
            open_stop_id={@open_stop_id}
            trip_id={@trip_id}
            user_id={@user_id}
          />
        </div>

        <div class={classes(["faces", open: @members_open, flush: !@panel_open])}>
          <button
            class="facepile"
            type="button"
            aria-label="Who is on this trip"
            $click="toggle_members"
          >
            <Faces present={@present} trip_id={@trip_id} user_id={@user_id} you={@initials} />
          </button>

          <span class="sep"></span>
          <LogOutButton cid="log_out" />
        </div>

        {%if @members_open}
          <div class={classes(["members", flush: !@panel_open])}>
            <MembersList
              cid="members_list"
              present={@present}
              trip_id={@trip_id}
              user_id={@user_id}
            />
          </div>
        {/if}

        {%if @mode == :placing}
          <document $key_down.escape="toggle_placing" />
        {/if}

        {%if @mode == :drawing}
          <document $key_down.escape="toggle_drawing" />
        {/if}

        {%if @details_open}
          <document $key_down.escape="close_details" />

          <TripDetails cid="trip_details" trip_id={@trip_id} user_id={@user_id} />
        {/if}

        {%if @open_stop_id}
          <document $key_down.escape="close_stop" />

          <StopEditor
            cid="stop_editor"
            away={!@panel_open}
            editing={@editing}
            stop_id={@open_stop_id}
            trip_id={@trip_id}
            tz_offset={@tz_offset}
            user_id={@user_id}
          />
        {/if}
      </div>
    </div>
    """
  end

  # The panel closes in this same action rather than a follow-up, so the editor is not left
  # open for a render on a row that is gone.
  def action(:delete_stop, params, component) do
    :ok = Trips.delete_stop(params.id)

    close_panel(component)
  end

  def action(:close_details, _params, component) do
    put_state(component, :details_open, false)
  end

  def action(:close_stop, _params, component) do
    close_panel(component)
  end

  # Nothing renders the panel after this.
  def action(:clear_stop, _params, component) do
    put_state(component, :open_stop_id, nil)
  end

  # Somebody else's pointer landed in a field, or left one, or they opened or closed a stop.
  def action(:editing_changed, params, component) do
    component
    |> put_state(
      editing: Presence.edit(component.state.editing, params),
      present: Presence.arrive(component.state.present, params)
    )
    |> watch(params)
  end

  # Kept on the page because the mark on the other screens names both the stop and the field,
  # and the open stop is the page's state.
  def action(:field_focused, params, component) do
    component
    |> put_state(:focused_field, params.field)
    |> announce_editing()
  end

  def action(:field_blurred, _params, component) do
    component
    |> put_state(:focused_field, nil)
    |> announce_editing()
  end

  # Keeps somebody's newest pointer position and queues a check that drops it unless a newer one
  # arrives first. `Offgrid.Presence` explains why this uses a sequence number.
  def action(:cursor_moved, params, component) do
    {cursors, seq} = Presence.cursor(component.state.cursors, params)

    component
    |> put_state(:cursors, cursors)
    |> put_action(
      name: :expire_cursor,
      params: %{id: params.id, seq: seq},
      delay: @cursor_expiry_ms
    )
  end

  def action(:expire_cursor, params, component) do
    put_state(
      component,
      :cursors,
      Presence.expire(component.state.cursors, params.id, params.seq)
    )
  end

  # Everything that needs the page on screen: the browser's clock offset and joining the trip's
  # channel.
  def action(:mounted, _params, component) do
    component
    |> put_state(:tz_offset, Device.utc_offset_minutes())
    |> join()
  end

  # The app is not told when a browser goes, so everyone keeps saying they are here and silence
  # means gone.
  def action(:heartbeat, _params, component) do
    said = said_something(component)

    said
    |> TripChannel.tell(:editing, whereabouts(said))
    |> put_action(name: :heartbeat, delay: @heartbeat_ms)
  end

  # Nothing newer from them within `@forget_after_ms`, so their face and their marks go.
  def action(:expire_person, params, component) do
    {present, editing} =
      Presence.depart(
        component.state.present,
        component.state.editing,
        params.id,
        params.seq
      )

    put_state(component, editing: editing, present: present)
  end

  # Tried again after a pause. The server refuses a trip it has not heard of, which a trip made
  # offline is until its batch lands.
  def action(:join_refused, _params, component) do
    if component.state.join_tries < @join_attempts do
      put_action(component, name: :rejoin, delay: @rejoin_ms)
    else
      component
    end
  end

  def action(:rejoin, _params, component) do
    join(component)
  end

  # Announces only once the subscription is in place. Subscribing in `init/3` let broadcasts land
  # in the previous page mid-navigation, and subscribing and announcing in one command lost
  # answers that arrived before this browser was listening on the channel.
  def action(:joined, _params, component) do
    said = said_something(component)

    said
    |> put_command(:announce, whereabouts(said))
    |> put_action(name: :heartbeat, delay: @heartbeat_ms)
  end

  # A click on the map, in hundredths of it. It places a stop when + has armed it, and
  # otherwise pings the place for everyone else on the trip.
  def action(:map_clicked, params, component) do
    if component.state.mode == :placing,
      do: place(component, params, read_trip(component)),
      else: ping(component, params)
  end

  # Everyone answers an arrival, so a newcomer learns who is here without anybody keeping a
  # list. Both messages carry what the person has open.
  def action(:member_arrived, params, component) do
    said = said_something(component)

    said
    |> put_command(:answer, whereabouts(said))
    |> put_state(
      editing: Presence.edit(component.state.editing, params),
      present: Presence.arrive(component.state.present, params)
    )
    |> watch(params)
  end

  # An answer to our own arrival. Only adds, so the round stops here.
  def action(:member_here, params, component) do
    component
    |> put_state(
      editing: Presence.edit(component.state.editing, params),
      present: Presence.arrive(component.state.present, params)
    )
    |> watch(params)
  end

  def action(:open_details, _params, component) do
    put_state(component, :details_open, true)
  end

  def action(:open_stop, params, component) do
    open_panel(component, params.id)
  end

  # Somebody else's ping. The sender's own is shown by `ping/2`, without waiting for this.
  def action(:show_ping, params, component) do
    component
    |> put_state(:ping, %{x: params.x, y: params.y})
    |> put_action(name: :clear_ping, delay: @ping_ms)
  end

  # A ping is a gesture, so nothing stores it. It lasts long enough for the ring to travel its
  # full width twice.
  def action(:clear_ping, _params, component) do
    put_state(component, :ping, nil)
  end

  def action(:toggle_maps, _params, component) do
    put_state(component, :maps_open, !component.state.maps_open)
  end

  def action(:toggle_members, _params, component) do
    put_state(component, :members_open, !component.state.members_open)
  end

  def action(:toggle_drawing, _params, component) do
    put_state(component, mode: toggle(component.state.mode, :drawing), ping: nil)
  end

  # + arms placing rather than creating a stop, and a second press disarms it. The click on the
  # map creates the stop.
  def action(:toggle_placing, _params, component) do
    put_state(component, :mode, toggle(component.state.mode, :placing))
  end

  # Called after mount, never from `init/3` - see `:joined`.
  def command(:join, params, server) do
    if TripChannel.on_trip?(server, params.trip_id) do
      server
      |> put_subscription({:trip, params.trip_id})
      |> put_action(:joined)
    else
      put_action(server, :join_refused)
    end
  end

  def command(:announce, params, server) do
    relay_presence(server, params, :member_arrived)
  end

  def command(:answer, params, server) do
    relay_presence(server, params, :member_here)
  end

  def command(:editing, params, server) do
    relay_presence(server, params, :editing_changed)
  end

  def command(:ping, params, server) do
    TripChannel.relay(server, params.trip_id, :show_ping, x: params.x, y: params.y)
  end

  # Tells the others which stop and field this browser has open. Called last in every action
  # that changes either, so the message carries the state the action left behind.
  defp announce_editing(component) do
    said = said_something(component)

    TripChannel.tell(said, :editing, whereabouts(said))
  end

  # The panel closes now and the stop is let go after the slide, so the panel has something to
  # draw on its way out. The others are told at once.
  defp close_panel(component) do
    component
    |> put_state(focused_field: nil, panel_open: false)
    |> announce_editing()
    |> put_action(name: :clear_stop, delay: @panel_slide_ms)
  end

  # Asks for the subscription and counts the asking, so a refusal knows when to stop.
  defp join(component) do
    component
    |> put_state(:join_tries, component.state.join_tries + 1)
    |> put_command(:join, trip_id: component.state.trip_id)
  end

  defp open_panel(component, stop_id) do
    component
    |> put_state(focused_field: nil, open_stop_id: stop_id, panel_open: true)
    |> announce_editing()
  end

  # What the panel shows, not what the page still holds, so the others see the stop close when
  # the panel starts to slide out.
  defp open_stop(%{panel_open: false}), do: nil

  defp open_stop(state), do: state.open_stop_id

  defp ping(component, %{x: x, y: y}) do
    component
    |> put_state(:ping, %{x: x, y: y})
    |> put_action(name: :clear_ping, delay: @ping_ms)
    |> TripChannel.tell(:ping, trip_id: component.state.trip_id, x: x, y: y)
  end

  # No readable trip, nowhere to put a stop, so the click only disarms +.
  defp place(component, _place, nil), do: put_state(component, :mode, :idle)

  # The hundredths are offsets in a box a hundred wide, so the projection needs no other size.
  defp place(component, %{x: x, y: y}, trip) do
    {lat, lng} = Geo.from_offset(x, y, 100, 100, trip.basemap)

    {:ok, stop} =
      %{date: trip.starts_on, lat: lat, lng: lng, name: "New stop", trip_id: trip.id}
      |> Stop.new()
      |> DB.create()

    component
    |> put_state(:mode, :idle)
    |> open_panel(stop.id)
  end

  defp read_trip(component) do
    component.state.trip_id
    |> Queries.trip_with_basemap()
    |> DB.read()
  end

  defp relay_presence(server, params, action) do
    TripChannel.relay(
      server,
      params.trip_id,
      action,
      TripChannel.sender(server) ++
        [stop_id: params.stop_id, field: params.field, seq: params.seq]
    )
  end

  # Numbers this browser's presence messages, so a stale one can be told from a newer one.
  defp said_something(component) do
    put_state(component, :presence_seq, component.state.presence_seq + 1)
  end

  # Arming the mode that is already on disarms it.
  defp toggle(mode, mode), do: :idle

  defp toggle(_mode, armed), do: armed

  # Every message from somebody queues a check carrying its number, which lets them go unless
  # they have said something newer by then.
  defp watch(component, %{id: id, seq: seq}) do
    put_action(component,
      name: :expire_person,
      params: %{id: id, seq: seq},
      delay: @forget_after_ms
    )
  end

  # What this browser has open, for every presence message. The server adds who it is.
  defp whereabouts(component) do
    state = component.state

    [
      trip_id: state.trip_id,
      stop_id: open_stop(state),
      field: state.focused_field,
      seq: state.presence_seq
    ]
  end
end
