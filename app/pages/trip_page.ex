defmodule Offgrid.Pages.TripPage do
  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  Everything drawn here is a row in the browser's own database, except three gestures that are
  not records: the stroke being drawn, the ping, and who is here. Those live in this page's
  state and travel as broadcasts on the trip's channel.

  The page holds the screen's modes (placing a stop, drawing) and the ids the panels are open
  on. Each component under it reads its own rows through its own query. A page cannot hold a
  query prop, which is why the header, the itinerary and the layers are components.
  """

  use Hologram.Page
  use Hologram.DB

  alias Hologram.Auth
  alias Offgrid.Box
  alias Offgrid.Cast
  alias Offgrid.Clock
  alias Offgrid.Components.Cursors
  alias Offgrid.Components.Faces
  alias Offgrid.Components.Ink
  alias Offgrid.Components.MapPicker
  alias Offgrid.Components.MapPins
  alias Offgrid.Components.MapRoute
  alias Offgrid.Components.MembersList
  alias Offgrid.Components.StopEditor
  alias Offgrid.Components.StopsList
  alias Offgrid.Components.Terrain
  alias Offgrid.Components.TripDetails
  alias Offgrid.Components.TripHeader
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User
  alias Offgrid.Geo
  alias Offgrid.Link
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Presence
  alias Offgrid.Stroke

  # How often a browser says it is still here, and how long the others wait before letting it
  # go. The ratio is the safety margin: four beats fit in the window, so two late beats in a row
  # do not drop somebody. Each beat is a render on every other screen, so it cannot be shorter.
  @heartbeat_ms 500
  @forget_after_ms 2_000

  # How often this browser sends its pointer position while it moves. It has its own timer
  # because a throttled event dispatches on both edges of its window, which sent positions in
  # bursts. The timer stops when a tick finds nothing new to send.
  @cursor_ms 100

  # Somebody else's pointer is dropped when nothing newer has arrived in this long.
  @cursor_expiry_ms 2_500

  # How long the stop panel takes to slide out, which is how long the page keeps the stop it
  # was open on. The stylesheet's `.editor` transition runs for the same time.
  @panel_slide_ms 250

  @ping_ms 3_000

  # A join the server refuses is asked again after a pause, up to this many joins in all.
  @join_attempts 2
  @rejoin_ms 3_000

  # The theme's own five: the three the people on a trip are drawn in, the accent, and ink.
  @ink_colors ["#ff2d55", "#af52de", "#30b0c7", "#007aff", "#1d1d1f"]

  route "/trips/:id"

  param :id, :string

  layout Offgrid.DefaultLayout

  middleware Offgrid.Middleware.RequireSession

  # Nothing here checks that the id names a trip this person may see. The queries are the
  # check, and the trip's rules give them no rows for a trip that is not theirs.
  def init(params, component, server) do
    initialized =
      component
      |> put_state(
        box: nil,
        cursors: %{},
        details_open: false,
        drag: nil,
        drag_rect: nil,
        drawing: false,
        editing: %{},
        editing_seq: 0,
        focused_field: nil,
        ink_color: hd(@ink_colors),
        join_tries: 0,
        maps_open: false,
        members_open: false,
        open_stop_id: nil,
        panel_open: false,
        ping: nil,
        placing: false,
        pointer: nil,
        pointer_sent: nil,
        pointer_ticking: false,
        present: [],
        stroke: [],
        stroke_box: nil,
        trip_id: params.id,
        tz_offset: 0,
        user_id: server.user_id,
        you: initials(server.user_id)
      )
      # Runs on the client after the first render. A component may queue one action, so
      # everything that needs the page on screen shares it.
      |> put_action(:mounted)

    {initialized, server}
  end

  # The canvas is an empty element laid over the terrain rather than wrapped around it, because
  # a click inside a child component does not reach a listener on the element around it.
  #
  # The canvas is measured on window resize: a window binding goes with the page, while a
  # `$resize` on the canvas fires once more as the element goes and lands on the next page.
  #
  # A drag outlives the pin it began on, so its pointer is followed on the document.
  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain trip_id={@trip_id} />

        <div
          id="canvas"
          class={canvas_class(@placing)}
          $click="place_stop"
          $pointer_move.throttle(50)="point"
        ></div>

        <MapRoute cid="map_route" drag={@drag} trip_id={@trip_id} />

        <div
          class={ink_class(@drawing)}
          style={nib_cursor(@drawing, @ink_color)}
          $pointer_down="ink_start"
          $pointer_move="ink_extend"
          $pointer_up="ink_finish"
        ></div>

        <Ink cid="ink" drawing={@drawing} trip_id={@trip_id} user_id={@user_id} />

        <svg class="ink-paper" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
          {%if @stroke != []}
            <path
              d={stroke_path(@stroke)}
              stroke={@ink_color}
              fill="none"
              vector-effect="non-scaling-stroke"
            />
          {/if}
        </svg>

        <MapPins
          cid="map_pins"
          drag={@drag}
          open_stop_id={@open_stop_id}
          trip_id={@trip_id}
        />

        <Cursors cid="cursors" cursors={@cursors} trip_id={@trip_id} user_id={@user_id} />

        {%if @ping}
          <div class="ping" style={"left:#{@ping.x}%;top:#{@ping.y}%"}>
            <i class="wash"></i><i class="edge"></i><b></b>
          </div>
        {/if}

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

        <div class={faces_class(@members_open, @panel_open)}>
          <button
            class="facepile"
            type="button"
            aria-label="Who is on this trip"
            $click="toggle_members"
          >
            <Faces
              cid="faces"
              present={@present}
              trip_id={@trip_id}
              user_id={@user_id}
              you={@you}
            />
          </button>

          <span class="sep"></span>
          <button class="signout" type="button" $click="log_out">Log out</button>
        </div>

        {%if @members_open}
          <div class={members_class(@panel_open)}>
            <MembersList
              cid="members_list"
              present={@present}
              trip_id={@trip_id}
              user_id={@user_id}
            />
          </div>
        {/if}

        <button
          class={pen_class(@drawing, @panel_open)}
          style={pen_style(@drawing, @ink_color)}
          type="button"
          aria-label="Draw"
          $click="toggle_drawing"
        >
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M4.5 19.5 L7.5 12 L15.5 4 L20 8.5 L12 16.5 Z" />
            <path class="solid" d="M4.5 19.5 L8.6 18 L6 15.4 Z" />
          </svg>
        </button>

        {%if @drawing}
          <div class={cpop_class(@panel_open)}>
            {%for color <- ink_colors()}
              <button
                class={cdot_class(color, @ink_color)}
                type="button"
                style={"background:#{color}"}
                aria-label={color}
                $click={:pick_color, color: color}
              ></button>
            {/for}
          </div>
        {/if}

        <window $resize="measure" />

        {%if @drag}
          <document $pointer_move="drag_move" $pointer_up="drag_finish" />
        {/if}

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

  # The remarks go first because the reference restricts rather than cascades, so the server
  # refuses a stop deleted on its own. One batch, so nobody sees it half done.
  #
  # The panel closes in this same action rather than a follow-up, so the editor is not left
  # open for a render on a row that is gone.
  def action(:delete_stop, params, component) do
    Comment
    |> filter(stop_id: params.id)
    |> DB.read()
    |> Enum.each(&(:ok = DB.delete(Comment, &1.id)))

    :ok = DB.delete(Stop, params.id)

    # The row is already gone, so the panel slides out empty.
    component
    |> put_state(focused_field: nil, panel_open: false)
    |> announce_editing()
    |> put_action(name: :clear_stop, delay: @panel_slide_ms)
  end

  def action(:close_details, _params, component) do
    put_state(component, :details_open, false)
  end

  # The panel closes now and the stop is let go after the slide, so the panel has something to
  # draw on its way out. The others are told at once.
  def action(:close_stop, _params, component) do
    component
    |> put_state(focused_field: nil, panel_open: false)
    |> announce_editing()
    |> put_action(name: :clear_stop, delay: @panel_slide_ms)
  end

  # Nothing renders the panel after this.
  def action(:clear_stop, _params, component) do
    put_state(component, :open_stop_id, nil)
  end

  # The map's place in the window is read once, when a pin is pressed, and held for the drag.
  # The row is written only when the pointer lifts, not on every move.
  def action(:drag_start, params, component) do
    put_state(component,
      drag: %{id: params.id, x: nil, y: nil},
      drag_rect: Box.rect("canvas")
    )
  end

  # In hundredths of the map, which is what the pin's style takes, whatever the map's size.
  def action(:drag_move, params, component) do
    {left, top, width, height} = component.state.drag_rect
    event = params.event

    put_state(component, :drag, %{
      component.state.drag
      | x: (event.client_x - left) / width * 100,
        y: (event.client_y - top) / height * 100
    })
  end

  # A press that never moved writes nothing. It is a click, and the pin's own binding opens the
  # stop, as it also does when a drag ends over the pin.
  def action(:drag_finish, _params, component) do
    drop(component, component.state.drag)
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

  def action(:log_out, _params, component) do
    put_command(component, :log_out)
  end

  def action(:logged_out, _params, component) do
    put_page(component, LogInPage)
  end

  # While drawn, a stroke stays in screen space (hundredths of the map), so a move is one
  # division. It becomes map coordinates when saved, the only moment the map's bounds matter.
  def action(:ink_extend, params, component) do
    if component.state.stroke_box do
      put_state(
        component,
        :stroke,
        extend(component.state.stroke, ink_point(component, params.event))
      )
    else
      component
    end
  end

  # Lifting the pointer saves the stroke and drops the local copy, since the saved layer draws
  # it from then on. A stroke of one point is a tap, not a line, and is not saved.
  def action(:ink_finish, _params, component) do
    finish(component, Enum.reverse(component.state.stroke))
  end

  # The box is read once, when the pointer goes down, and held for the stroke.
  #
  # Whether the pen is armed is checked here rather than left to the layer's `pointer-events`,
  # which only decides what the pointer hits.
  def action(:ink_start, params, component) do
    if component.state.drawing do
      started = put_state(component, :stroke_box, Box.size("canvas"))

      put_state(started, :stroke, [ink_point(started, params.event)])
    else
      component
    end
  end

  # Runs on every window resize, so the box in state always matches the canvas.
  def action(:measure, _params, component) do
    put_state(component, :box, Box.size("canvas"))
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

  # Only remembered here. `:send_pointer` sends it on its own timer.
  #
  # Only the empty canvas hears the pointer, so over a pin, the panel, the armed ink layer or
  # off the map, the last position fades on the other screens.
  def action(:point, params, component) do
    case component.state.box do
      nil ->
        component

      {width, height} ->
        moved =
          put_state(component, :pointer, %{
            x: params.event.offset_x / width * 100,
            y: params.event.offset_y / height * 100
          })

        if moved.state.pointer_ticking, do: moved, else: start_pointing(moved)
    end
  end

  # A tick with nothing new to send is the last one until the pointer moves again.
  def action(:send_pointer, _params, component) do
    state = component.state

    if state.pointer && state.pointer != state.pointer_sent do
      component
      |> put_state(:pointer_sent, state.pointer)
      |> tell(:cursor,
        trip_id: state.trip_id,
        x: state.pointer.x,
        y: state.pointer.y
      )
      |> put_action(name: :send_pointer, delay: @cursor_ms)
    else
      put_state(component, :pointer_ticking, false)
    end
  end

  # Everything that needs the page on screen: the canvas to measure, the browser's clock offset,
  # and joining the trip's channel.
  def action(:mounted, _params, component) do
    component
    |> put_state(box: Box.size("canvas"), tz_offset: Clock.offset_minutes())
    |> join()
  end

  # The app is not told when a browser goes, so everyone keeps saying they are here and silence
  # means gone.
  def action(:heartbeat, _params, component) do
    said = said_something(component)

    said
    |> tell(:editing, whereabouts(said))
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
    component
    |> put_state(focused_field: nil, open_stop_id: params.id, panel_open: true)
    |> announce_editing()
  end

  # A click on the map places a stop when + has armed it, and otherwise pings the place for
  # everyone else on the trip.
  def action(:place_stop, params, component) do
    if component.state.placing,
      do: place(component, params.event),
      else: ping(component, params.event)
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

  def action(:pick_color, params, component) do
    put_state(component, :ink_color, params.color)
  end

  def action(:toggle_members, _params, component) do
    put_state(component, :members_open, !component.state.members_open)
  end

  # Placing and drawing are exclusive, so arming one disarms the other.
  def action(:toggle_drawing, _params, component) do
    put_state(component,
      drawing: !component.state.drawing,
      ping: nil,
      placing: false,
      stroke: [],
      stroke_box: nil
    )
  end

  # + arms placing rather than creating a stop, and a second press disarms it. The click on the
  # map creates the stop.
  def action(:toggle_placing, _params, component) do
    put_state(component, drawing: false, placing: !component.state.placing)
  end

  # Called after mount, never from `init/3` - see `:joined`.
  #
  # Realtime channels do no authorization, and the trip's rules hide rows, not broadcasts. So
  # every command that names the channel checks `on_trip?/2` first.
  def command(:join, params, server) do
    if on_trip?(server, params.trip_id) do
      server
      |> put_subscription({:trip, params.trip_id})
      |> put_action(:joined)
    else
      put_action(server, :join_refused)
    end
  end

  # Who a presence message is from comes from the session, never from the params - otherwise
  # any member could speak as another.
  def command(:announce, params, server) do
    if on_trip?(server, params.trip_id) do
      put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, params.trip_id},
        :member_arrived,
        sender(server) ++ [stop_id: params.stop_id, field: params.field, seq: params.seq]
      )
    else
      server
    end
  end

  def command(:answer, params, server) do
    if on_trip?(server, params.trip_id) do
      put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, params.trip_id},
        :member_here,
        sender(server) ++ [stop_id: params.stop_id, field: params.field, seq: params.seq]
      )
    else
      server
    end
  end

  def command(:editing, params, server) do
    if on_trip?(server, params.trip_id) do
      put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, params.trip_id},
        :editing_changed,
        sender(server) ++ [stop_id: params.stop_id, field: params.field, seq: params.seq]
      )
    else
      server
    end
  end

  def command(:cursor, params, server) do
    if on_trip?(server, params.trip_id) do
      put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, params.trip_id},
        :cursor_moved,
        sender(server) ++ [x: params.x, y: params.y]
      )
    else
      server
    end
  end

  # The broadcast leaves out the session that sent it, which has already drawn its own.
  def command(:ping, params, server) do
    if on_trip?(server, params.trip_id) do
      put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, params.trip_id},
        :show_ping,
        x: params.x,
        y: params.y
      )
    else
      server
    end
  end

  # A command, because only the server can write the session.
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

  defp cdot_class(color, color), do: "cdot on"

  defp cdot_class(_color, _chosen), do: "cdot"

  defp ink_class(true), do: "ink on"

  defp ink_class(false), do: "ink"

  # A pen nib in the loaded ink. The hotspot (`3 23`) sits on the nib's point rather than the
  # image's corner, so the line starts where it was aimed.
  #
  # The colour's `#` is percent-encoded, since a raw `#` in a data URI starts a fragment and
  # cuts the SVG short.
  defp nib_cursor(false, _ink_color), do: nil

  defp nib_cursor(true, "#" <> rgb) do
    svg =
      "<svg xmlns='http://www.w3.org/2000/svg' width='26' height='26'>" <>
        "<path d='M3 23 L6.5 14.5 L17.5 3.5 L22.5 8.5 L11.5 19.5 Z' fill='%23#{rgb}'" <>
        " stroke='white' stroke-width='1.6' stroke-linejoin='round'/>" <>
        "<path d='M3 23 L7.5 21 L5 18.5 Z' fill='white'/></svg>"

    "cursor: url(\"data:image/svg+xml;utf8,#{svg}\") 3 23, cell"
  end

  defp ink_colors, do: @ink_colors

  # Skips a point within half a percent of the last one, since every kept point costs time on
  # every render. Manhattan distance, because this runs on every pointer event.
  defp extend([{last_x, last_y} | _rest] = stroke, {x, y} = point) do
    if abs(x - last_x) + abs(y - last_y) < 0.5, do: stroke, else: [point | stroke]
  end

  defp extend(stroke, point), do: [point | stroke]

  defp ink_point(component, event) do
    {width, height} = component.state.stroke_box

    {event.offset_x / width * 100, event.offset_y / height * 100}
  end

  defp finish(component, [_single_point]), do: idle_stroke(component)

  defp finish(component, []), do: idle_stroke(component)

  defp finish(component, points) do
    trip =
      Trip
      |> filter(id: component.state.trip_id)
      |> include(:basemap)
      |> one()
      |> DB.read()

    save_stroke(component, points, trip)
  end

  # No readable trip, as for a stranger, so the stroke is dropped the way a tap is.
  defp save_stroke(component, _points, nil), do: idle_stroke(component)

  defp save_stroke(component, points, trip) do
    {:ok, _sketch} =
      %{
        author_id: component.state.user_id,
        color: component.state.ink_color,
        points: sketch_path(points, trip),
        trip_id: trip.id
      }
      |> Sketch.new()
      |> DB.create()

    idle_stroke(component)
  end

  # Asks for the subscription and counts the asking, so a refusal knows when to stop.
  defp join(component) do
    component
    |> put_state(:join_tries, component.state.join_tries + 1)
    |> put_command(:join, trip_id: component.state.trip_id)
  end

  defp idle_stroke(component) do
    put_state(component, stroke: [], stroke_box: nil)
  end

  defp ping(component, event) do
    {width, height} = component.state.box
    x = event.offset_x / width * 100
    y = event.offset_y / height * 100

    component
    |> put_state(:ping, %{x: x, y: y})
    |> put_action(name: :clear_ping, delay: @ping_ms)
    |> tell(:ping, trip_id: component.state.trip_id, x: x, y: y)
  end

  # Tells the others which stop and field this browser has open. Called last in every action
  # that changes either, so the message carries the state the action left behind.
  defp announce_editing(component) do
    said = said_something(component)

    tell(said, :editing, whereabouts(said))
  end

  defp start_pointing(component) do
    component
    |> put_state(:pointer_ticking, true)
    |> put_action(name: :send_pointer, delay: @cursor_ms)
  end

  # Every message from somebody queues a check carrying its number, which lets them go unless
  # they have said something newer by then.
  defp watch(component, %{id: id, seq: seq}) do
    put_action(component,
      name: :expire_person,
      params: %{id: id, seq: seq},
      delay: @forget_after_ms
    )
  end

  # Numbers this browser's presence messages, so a stale one can be told from a newer one.
  defp said_something(component) do
    put_state(component, :editing_seq, component.state.editing_seq + 1)
  end

  # What this browser has open, for every presence message. The server adds who it is.
  defp whereabouts(component) do
    state = component.state

    [
      trip_id: state.trip_id,
      stop_id: open_stop(state),
      field: state.focused_field,
      seq: state.editing_seq
    ]
  end

  # What the panel shows, not what the page still holds, so the others see the stop close when
  # the panel starts to slide out.
  defp open_stop(%{panel_open: false}), do: nil

  defp open_stop(state), do: state.open_stop_id

  # A gesture is sent only while online. A command that cannot reach the server raises, and a
  # ping or a pointer position is not worth an error.
  defp tell(component, command, params) do
    if Link.online?(), do: put_command(component, command, params), else: component
  end

  # The trip's own read rule, checked against the server's grants. A trip the server has not
  # heard of answers no, which is what the retry in `:join_refused` is for.
  defp on_trip?(server, trip_id) do
    Auth.can?(server.user_id, :read, %Trip{id: trip_id})
  end

  defp sender(server) do
    [id: server.user_id, initials: initials(server.user_id)]
  end

  defp pen_class(drawing, panel_open), do: "pen" <> armed(drawing) <> mid(panel_open)

  # The armed pen takes the loaded ink. The ring, not the colour, says it is armed, because
  # black is one of the inks and the resting button is already black.
  defp pen_style(false, _ink_color), do: nil

  defp pen_style(true, ink_color), do: "background:#{ink_color}"

  defp armed(true), do: " on"

  defp armed(false), do: ""

  # The SVG path a sketch is stored as, in map coordinates: longitude across, latitude negated
  # to run down. The percentages are offsets in a box a hundred wide, so no other size is needed.
  defp sketch_path(points, trip) do
    points
    |> Enum.map(fn {x, y} ->
      {lat, lng} = Geo.from_offset(x, y, 100, 100, trip.basemap)

      {lng, -lat}
    end)
    |> Stroke.path()
  end

  # The points are held newest first, because a stroke grows by prepending.
  defp stroke_path(stroke) do
    stroke
    |> Enum.reverse()
    |> Stroke.path()
  end

  # The pill takes an accent ring while the members panel it opens is up.
  defp faces_class(members_open, panel_open) do
    "faces" <> ring(members_open) <> mid(panel_open)
  end

  # The colours move with the pen, so they do not draw over the panel when it pushes the pen.
  defp cpop_class(panel_open), do: "cpop" <> mid(panel_open)

  defp members_class(panel_open), do: "members" <> mid(panel_open)

  # With no panel out, the controls on the right sit at the window's edge. They follow the
  # panel rather than the open stop, so they move together with it.
  defp mid(false), do: " mid"

  defp mid(true), do: ""

  defp ring(true), do: " open"

  defp ring(false), do: ""

  # The session names a user, but the account behind it may since have gone.
  defp initials(user_id) do
    user =
      User
      |> filter(id: user_id)
      |> one()
      |> DB.read()

    if user, do: Cast.initials(user.name)
  end

  # A drag that went nowhere leaves the row alone.
  defp drop(component, %{x: nil}), do: idle_drag(component)

  defp drop(component, drag) do
    trip =
      Trip
      |> filter(id: component.state.trip_id)
      |> include(:basemap)
      |> one()
      |> DB.read()

    write_place(component, drag, trip)
  end

  # No readable trip, nothing to move.
  defp write_place(component, _drag, nil), do: idle_drag(component)

  # The hundredths are offsets in a box a hundred wide, as in `sketch_path/2`.
  defp write_place(component, drag, trip) do
    {lat, lng} = Geo.from_offset(drag.x, drag.y, 100, 100, trip.basemap)

    :ok = DB.update(Stop, drag.id, %{lat: lat, lng: lng})

    idle_drag(component)
  end

  defp idle_drag(component) do
    put_state(component, drag: nil, drag_rect: nil)
  end

  defp place(component, event) do
    trip =
      Trip
      |> filter(id: component.state.trip_id)
      |> include(:basemap)
      |> one()
      |> DB.read()

    place(component, event, trip)
  end

  # No readable trip, nowhere to put a stop, so the click only disarms +.
  defp place(component, _event, nil), do: put_state(component, :placing, false)

  defp place(component, event, trip) do
    {width, height} = component.state.box

    {lat, lng} = Geo.from_offset(event.offset_x, event.offset_y, width, height, trip.basemap)

    {:ok, stop} =
      %{date: trip.starts_on, lat: lat, lng: lng, name: "New stop", trip_id: trip.id}
      |> Stop.new()
      |> DB.create()

    component
    |> put_state(focused_field: nil, open_stop_id: stop.id, panel_open: true, placing: false)
    |> announce_editing()
  end
end
