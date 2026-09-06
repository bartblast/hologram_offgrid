defmodule Offgrid.Pages.TripPage do
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

  @moduledoc """
  The trip planning screen: the map, the itinerary panel over it, and the people on it.

  Everything drawn here is a row read from the browser's own database - the stops, their
  pins, the route through them, everyone's ink - except three things that are gestures
  rather than records: the stroke being drawn right now, the ping, and who is here. Those
  live in this page's state and travel as broadcasts on the trip's channel.

  The page holds the screen's modes (placing a stop, drawing) and the ids the panels are open
  on; every component under it reads its own rows through its own query. The page cannot hold
  a query prop, which is why the header, the itinerary and the layers are components.
  """

  route "/trips/:id"

  param :id, :string

  layout Offgrid.DefaultLayout

  middleware Offgrid.Middleware.RequireSession

  # init/3 runs on the server on every page load, client-side navigations included, so the
  # session's user is readable here and the row it names can be looked up.
  #
  # The trip comes from the address rather than from a lookup. Nothing here checks that the id
  # names a trip this person may see: the queries below it are the check, and they answer with
  # the rows the trip's own rules allow - none, for a trip that is not theirs.
  def init(params, component, server) do
    initialized =
      component
      |> put_state(:box, nil)
      |> put_state(:cursors, %{})
      |> put_state(:drag, nil)
      |> put_state(:drag_rect, nil)
      |> put_state(:details_open, false)
      |> put_state(:drawing, false)
      |> put_state(:editing, %{})
      |> put_state(:editing_seq, 0)
      |> put_state(:focused_field, nil)
      |> put_state(:ink_color, "#ff2d55")
      |> put_state(:join_tries, 0)
      |> put_state(:maps_open, false)
      |> put_state(:members_open, false)
      |> put_state(:open_stop_id, nil)
      |> put_state(:panel_open, false)
      |> put_state(:ping, nil)
      |> put_state(:present, [])
      |> put_state(:placing, false)
      |> put_state(:stroke, [])
      |> put_state(:stroke_box, nil)
      |> put_state(:trip_id, params.id)
      |> put_state(:tz_offset, 0)
      |> put_state(:user_id, server.user_id)
      |> put_state(:you, initials(server.user_id))
      # Queued here and run on the client the moment the page is up, after its first render -
      # the framework's answer to "on mount". A component may queue one action, so the two
      # things that can only happen once the page is real share it.
      |> put_action(:mounted)

    {initialized, server}
  end

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain trip_id={@trip_id} />

        <!-- The surface a click lands on, laid over the terrain rather than wrapped around it: a
             click whose target sits inside a child component does not reach a listener on the
             element around it, so the surface is a plain element with nothing inside. -->
        <div
          id="canvas"
          class={canvas_class(@placing)}
          $click="place_stop"
          $pointer_move.throttle(100)="point"
        ></div>

        <MapRoute cid="map_route" drag={@drag} trip_id={@trip_id} />

        <!-- The pointer carries the nib, in the ink it is loaded with, so what the hand is
             about to do is under the hand rather than described somewhere else. -->
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
            <!-- In the ink it is being drawn with, not the accent: the colour was fixed here
                 while the mockup had one colour for your own ink, and the picker that arrived
                 later never reached it - so a violet line was drawn red and turned violet the
                 moment the pointer lifted. -->
            <path
              class="ink-mine"
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

        <!-- Three parts, in the order they are drawn: the wash that spreads, the hairline
             riding its edge, and the dot last so both pass behind it rather than tinting it. -->
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
                <!-- Drawn rather than typed. A font's "+" sits on its own maths axis, which is
                     not the middle of the circle around it, so the glyph reads a hair high
                     however the text box is centred - two strokes cannot. -->
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

          {%if @you}
            <span class="sep"></span>
            <button class="signout" type="button" $click="log_out">Log out</button>
          {/if}
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
          <!-- The same nib the pointer carries while the pen is out, so the control and the
               cursor are one object. Drawn rather than typed: the character it used to be is a
               font's, thin wherever the font is thin, and it read as barely there. -->
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

        <!-- The canvas only ever resizes with the window, and a window binding is torn down with
             the page, where an observer on the canvas fires once more as the element goes and
             lands on whichever page comes next. -->
        <window $resize="measure" />

        <!-- A drag outlives the pin it began on, so the pointer is followed on the document
             rather than on the pin: the hand can wander over another pin, the panel or off the
             map entirely and the stop still goes where it is let go. Listening only while a
             drag is under way, so nothing is bound the rest of the time. -->
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

  # Deleting closes in the SAME action, not through a follow-up: the editor renders the
  # row being deleted, so if it were still mounted for one render in between it would ask
  # the database for a row that is gone.
  #
  # The remarks go first. A remark names its stop and the reference restricts rather than
  # cascades, so a stop deleted on its own is refused by the server however cleanly the
  # browser showed it gone - and remarks-then-stop is also the only order another browser can
  # watch without seeing a remark on no stop. One batch, so nobody sees it half done.
  def action(:delete_stop, params, component) do
    Comment
    |> filter(stop_id: params.id)
    |> DB.read()
    |> Enum.each(&(:ok = DB.delete(Comment, &1.id)))

    :ok = DB.delete(Stop, params.id)

    # Out the same way it came in. The row is gone this instant, so the panel slides away
    # empty - which is honest, since the thing it was about no longer exists - rather than
    # holding a copy of something deleted or blinking out where closing glides.
    component
    |> put_state(:focused_field, nil)
    |> put_state(:panel_open, false)
    |> announce_editing()
    |> put_action(name: :clear_stop, delay: 250)
  end

  def action(:close_details, _params, component) do
    put_state(component, :details_open, false)
  end

  # The panel is told to leave, and the stop it was open on is let go a moment later - so it
  # still has something to draw while it slides out. Everything else about closing happens
  # now: the field is no longer focused and the others are told so at once.
  def action(:close_stop, _params, component) do
    component
    |> put_state(:focused_field, nil)
    |> put_state(:panel_open, false)
    |> announce_editing()
    |> put_action(name: :clear_stop, delay: 250)
  end

  # What the slide was waiting for. Nothing renders the panel after this.
  def action(:clear_stop, _params, component) do
    put_state(component, :open_stop_id, nil)
  end

  # A pin was pressed. The map's place in the window is read once, here, and held for the
  # length of the drag - every move after it is arithmetic, the way an ink stroke's is.
  #
  # Nothing is written yet, and the row is not touched until the pointer lifts: a write per
  # frame would be a hundred rows on the wire for one gesture, where the stop only ever
  # ends up in one place.
  def action(:drag_start, params, component) do
    component
    |> put_state(:drag, %{id: params.id, x: nil, y: nil})
    |> put_state(:drag_rect, Box.rect("canvas"))
  end

  # The pin follows the pointer, in hundredths of the map, which is what the pin's own style
  # wants and what makes this independent of the map's size.
  def action(:drag_move, params, component) do
    {left, top, width, height} = component.state.drag_rect
    event = params.event

    put_state(component, :drag, %{
      component.state.drag
      | x: (event.client_x - left) / width * 100,
        y: (event.client_y - top) / height * 100
    })
  end

  # Letting go is what makes the move real. A press that never moved is not a drag and writes
  # nothing - it is a click, and the pin's own binding opens the stop, which is also what a
  # finished drag does, since the pointer comes up over the pin it is holding.
  def action(:drag_finish, _params, component) do
    drop(component, component.state.drag)
  end

  # Somebody else's pointer landed in a field, or left one, or they opened or closed a stop.
  def action(:editing_changed, params, component) do
    put_state(component, :editing, Presence.edit(component.state.editing, params))
  end

  # This browser's pointer landed in a field of the open stop. Remembered here, on the page,
  # because the mark on the other screens is about the stop AND the field, and the stop is the
  # page's to know.
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

  # A stroke is kept in screen space while it is being drawn - hundredths of the map's width
  # and height - so a move costs one division and nothing else. It becomes real coordinates
  # when it is saved, which is the only moment the map's bounds matter.
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

  # Lifting the pointer is what makes the stroke a row. The screen-space points become real
  # coordinates here - the one moment the map's bounds matter - and the local copy is dropped
  # in the same breath, because from now on the saved layer draws it.
  #
  # A stroke of one point is a tap, not a line, and is not worth a row.
  def action(:ink_finish, _params, component) do
    finish(component, Enum.reverse(component.state.stroke))
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

  # The one place the app asks the DOM anything. Runs on every change of the canvas's size, so
  # the box in state is never the box of a window that has since been resized.
  def action(:measure, _params, component) do
    put_state(component, :box, Box.size("canvas"))
  end

  # Somebody's pointer moved over their map. Keep the newest place, and queue a check that
  # will drop it unless a newer one arrives first - see `Offgrid.Presence` for why a sequence
  # number rather than a clock or a leave event.
  def action(:cursor_moved, params, component) do
    {cursors, seq} = Presence.cursor(component.state.cursors, params)

    component
    |> put_state(:cursors, cursors)
    |> put_action(name: :expire_cursor, params: %{id: params.id, seq: seq}, delay: 2_500)
  end

  def action(:expire_cursor, params, component) do
    put_state(
      component,
      :cursors,
      Presence.expire(component.state.cursors, params.id, params.seq)
    )
  end

  # This browser's pointer moved over the map: say where, as a share of the map, at most ten
  # times a second. Nothing is drawn here - your own pointer is the real one.
  #
  # Only the empty canvas hears the pointer, so a pointer over a pin, the panel or the ink
  # layer with the pen armed sends nothing and the last position fades on the other screens.
  # A pointer that leaves the map fades the same way, since there is no leave event to tell.
  def action(:point, params, component) do
    case component.state.box do
      nil ->
        component

      {width, height} ->
        tell(component, :cursor,
          id: component.state.user_id,
          initials: component.state.you,
          trip_id: component.state.trip_id,
          x: params.event.offset_x / width * 100,
          y: params.event.offset_y / height * 100
        )
    end
  end

  # Everything that can only happen once the page is on screen. The box needs a rendered
  # element to measure, the clock's offset needs a browser to ask, and joining the trip needs
  # a page that is listening.
  def action(:mounted, _params, component) do
    measured =
      component
      |> put_state(:box, Box.size("canvas"))
      |> put_state(:tz_offset, Clock.offset_minutes())

    if component.state.you do
      join(measured)
    else
      measured
    end
  end

  # The door said no. Once more, a little later, and then no more: the server refuses a trip it
  # cannot see, and a trip this browser made offline is exactly that until its batch lands -
  # which it will have, three seconds on, if it is ever going to.
  def action(:join_refused, _params, component) do
    if component.state.join_tries < 2 do
      put_action(component, name: :rejoin, delay: 3_000)
    else
      component
    end
  end

  def action(:rejoin, _params, component) do
    join(component)
  end

  # The subscription is ours. Only now do we say hello.
  #
  # Two steps rather than one, and the order is the whole point. Subscribing in `init/3` opened
  # a window where this page's subscription existed while the PREVIOUS page was still on
  # screen, so a broadcast arriving mid-navigation was dispatched into a page with no such
  # action. Subscribing and announcing in ONE command lost the answers instead: a reply came
  # back within milliseconds of the subscription being applied, before this browser's event
  # stream was listening on the channel. This action runs only once the join has come back,
  # a whole round trip after the subscription, so nobody can answer us before we can hear.
  def action(:joined, _params, component) do
    said = said_something(component)

    put_command(said, :announce, whereabouts(said))
  end

  # Somebody arrived. Add them, and say back that we are here - one answer each, so a new
  # arrival learns the room without anybody keeping a list of it anywhere. Both the arrival
  # and the answer carry what the person has open, so a newcomer sees the marks at once.
  def action(:member_arrived, params, component) do
    said = said_something(component)

    said
    |> put_command(:answer, whereabouts(said))
    |> put_state(:present, Presence.arrive(component.state.present, params))
    |> put_state(:editing, Presence.edit(component.state.editing, params))
  end

  # An answer to our own arrival. Only adds, so the round stops here.
  def action(:member_here, params, component) do
    component
    |> put_state(:present, Presence.arrive(component.state.present, params))
    |> put_state(:editing, Presence.edit(component.state.editing, params))
  end

  def action(:open_details, _params, component) do
    put_state(component, :details_open, true)
  end

  def action(:open_stop, params, component) do
    component
    |> put_state(:focused_field, nil)
    |> put_state(:open_stop_id, params.id)
    |> put_state(:panel_open, true)
    |> announce_editing()
  end

  # The whole local-first claim in one function: the click becomes a place, the place becomes
  # a row in the client's own database, and the itinerary, the pin and the editor all read that
  # row in the same frame. Only then does any of it travel. Nothing here waits for the server.
  # A click on the map places a stop when the + has armed it, and otherwise points at a place
  # for everyone else on the trip - which is what a click on a map means when it means nothing
  # else. The plan wanted a double click and Hologram has no such event, and this is better
  # than the alternative anyway: no third mode, and the unarmed map stops being inert.
  def action(:place_stop, params, component) do
    if component.state.placing,
      do: place(component, params.event),
      else: ping(component, params.event)
  end

  # Shown here at once and sent to the others in the same breath, so the person pinging sees
  # what they did without waiting to hear back.
  def action(:show_ping, params, component) do
    component
    |> put_state(:ping, %{x: params.x, y: params.y})
    |> put_action(name: :clear_ping, delay: 3_000)
  end

  # A ping is a gesture, not a record: nothing stores it, and after three seconds it is gone
  # from every screen it reached. Three rather than two, so the ring has time to travel its
  # full width twice instead of being cut off part way through its first.
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

  # The two armed modes are exclusive: the map can be waiting for a place or waiting for ink,
  # and arming either is how you say which.
  def action(:toggle_drawing, _params, component) do
    component
    |> put_state(:drawing, !component.state.drawing)
    |> put_state(:ping, nil)
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

  # Subscribing happens here, from the client, after the page is mounted - never in `init/3`,
  # for the reason `:joined` explains. The answer is an action, which is what lets the page
  # know the subscription is in place before it announces itself.
  #
  # THE DOOR. Realtime does no authorization of its own: a channel is a name, and anybody who
  # asks is subscribed. The trip's rules keep a stranger's ROWS empty, but a broadcast is not a
  # row, so without this check somebody with no role on the trip would hear every arrival and
  # every ping - and could answer. Every command that names the channel asks the same question
  # the trip's `allow :read` answers, on the server, where the grants are.
  def command(:join, params, server) do
    if on_trip?(server, params.trip_id) do
      server
      |> put_subscription({:trip, params.trip_id})
      |> put_action(:joined)
    else
      put_action(server, :join_refused)
    end
  end

  def command(:announce, params, server) do
    if on_trip?(server, params.trip_id) do
      put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, params.trip_id},
        :member_arrived,
        id: params.id,
        initials: params.initials,
        stop_id: params.stop_id,
        field: params.field,
        seq: params.seq
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
        id: params.id,
        initials: params.initials,
        stop_id: params.stop_id,
        field: params.field,
        seq: params.seq
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
        id: params.id,
        initials: params.initials,
        stop_id: params.stop_id,
        field: params.field,
        seq: params.seq
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
        id: params.id,
        initials: params.initials,
        x: params.x,
        y: params.y
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

  defp cdot_class(color, color), do: "cdot on"

  defp cdot_class(_color, _chosen), do: "cdot"

  defp ink_class(true), do: "ink on"

  defp ink_class(false), do: "ink"

  # A pen nib drawn at the pointer, tip first, in whichever ink is loaded - so the cursor is
  # also the swatch. CSS has no pen keyword, so it is an SVG carried inline; the two numbers
  # after the url are the hotspot, which sits on the nib's point rather than the image's
  # corner, or the line would start a nib's width away from where it was aimed.
  #
  # The colour is spelled without its hash, which is put back percent-encoded: a `#` inside a
  # data URI starts a fragment and would cut the drawing in half.
  defp nib_cursor(false, _ink_color), do: nil

  defp nib_cursor(true, "#" <> rgb) do
    svg =
      "<svg xmlns='http://www.w3.org/2000/svg' width='26' height='26'>" <>
        "<path d='M3 23 L6.5 14.5 L17.5 3.5 L22.5 8.5 L11.5 19.5 Z' fill='%23#{rgb}'" <>
        " stroke='white' stroke-width='1.6' stroke-linejoin='round'/>" <>
        "<path d='M3 23 L7.5 21 L5 18.5 Z' fill='white'/></svg>"

    "cursor: url(\"data:image/svg+xml;utf8,#{svg}\") 3 23, cell"
  end

  # The theme's own five: the three the people on a trip are drawn in, the accent, and ink.
  defp ink_colors, do: ["#ff2d55", "#af52de", "#30b0c7", "#007aff", "#1d1d1f"]

  # A pointer reports far more places than a line needs, and every one of them is paid for
  # again on EVERY render for as long as the sketch exists - measured at about a fifth of a
  # millisecond per point, so a screen with a few hundred of them spends more time redrawing
  # ink than everything else together. A place within half a percent of the last one - some
  # seven pixels on a full screen - says nothing the curve through it does not already say.
  # Manhattan distance, because this runs per pointer event and a square root would buy
  # nothing at this scale.
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

  # No trip readable, no ink to keep. A stranger reaches this screen and its rules answer
  # nothing, so the tools have nothing to work on and say so by doing nothing - the stroke
  # is dropped the way a tap is.
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
    component
    |> put_state(:stroke, [])
    |> put_state(:stroke_box, nil)
  end

  defp ping(component, event) do
    {width, height} = component.state.box
    x = event.offset_x / width * 100
    y = event.offset_y / height * 100

    component
    |> put_state(:ping, %{x: x, y: y})
    |> put_action(name: :clear_ping, delay: 3_000)
    |> tell(:ping, trip_id: component.state.trip_id, x: x, y: y)
  end

  # Tells the others what this browser has open now - the stop and the field, or nothing.
  # Called at the end of every action that changes either, so the message always carries the
  # state the action left behind.
  defp announce_editing(component) do
    said = said_something(component)

    tell(said, :editing, whereabouts(said))
  end

  # Counts this browser's presence messages, so the one that lost a race can be told from the
  # one that won it. Every message goes out through here.
  defp said_something(component) do
    put_state(component, :editing_seq, component.state.editing_seq + 1)
  end

  # Who this browser is and what it has open, as every presence message carries it.
  defp whereabouts(component) do
    state = component.state

    [
      id: state.user_id,
      initials: state.you,
      trip_id: state.trip_id,
      stop_id: open_stop(state),
      field: state.focused_field,
      seq: state.editing_seq
    ]
  end

  # What the PANEL shows, not what the page still holds. Closing keeps the stop for a moment so
  # the panel has something to draw on its way out, and for that moment nothing is open as far
  # as anybody else is concerned - the ring on their itinerary goes when the hand leaves, not a
  # quarter second later.
  defp open_stop(%{panel_open: false}), do: nil

  defp open_stop(state), do: state.open_stop_id

  # A gesture is sent only while the browser has a network. A command that cannot reach the
  # server raises, and a ping or a pointer position is not worth an error - so with no network
  # it is shown here and told to nobody, which is the truth of the moment.
  defp tell(component, command, params) do
    if Link.online?(), do: put_command(component, command, params), else: component
  end

  # The trip's own read rule, asked on the server from the grants it holds. A trip the server
  # has never heard of answers no, which is what the retry in `:join_refused` is for.
  defp on_trip?(server, trip_id) do
    Auth.can?(server.user_id, :read, %Trip{id: trip_id})
  end

  defp pen_class(drawing, panel_open), do: "pen" <> armed(drawing) <> mid(panel_open)

  # The pen carries the ink it is loaded with, so a glance at the button says what the next
  # stroke will be - the picker is only on screen while the pen is out, and after that this is
  # the only thing that could say. Whether it is ARMED is the ring's job rather than the
  # colour's, because black is one of the five and the resting button is already black.
  defp pen_style(false, _ink_color), do: nil

  defp pen_style(true, ink_color), do: "background:#{ink_color}"

  defp armed(true), do: " on"

  defp armed(false), do: ""

  # Screen space to the line a sketch is stored AS: the whole stroke written once, as an SVG
  # path in the map's own coordinates - longitude across, latitude down, which is why it is
  # negated. Doing this here, once, is what lets the layer that draws it do nothing at all.
  # The percentages ARE offsets in a box a hundred wide, so the projection needs no other size.
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

  # The pill takes an accent ring while the panel it opens is up, so the faces read as the
  # control they are rather than as decoration that happened to be clicked.
  defp faces_class(members_open, panel_open) do
    "faces" <> ring(members_open) <> mid(panel_open)
  end

  # The colours belong to the pen, so they go where it goes - pinned to the window's edge they
  # stayed behind when the panel pushed the pen aside, and drew over the panel.
  defp cpop_class(panel_open), do: "cpop" <> mid(panel_open)

  defp members_class(panel_open), do: "members" <> mid(panel_open)

  # With no panel out there is nothing to clear, so the three controls on the right sit at the
  # window's edge - the mockup's own `mid`, drawn for exactly this and unused until now. They
  # follow the PANEL rather than the open stop, so they leave with it and come back with it,
  # which is what makes the two read as one movement.
  defp mid(false), do: " mid"

  defp mid(true), do: ""

  defp ring(true), do: " open"

  defp ring(false), do: ""

  # Nobody signed in has no face to show, which is a real state until the auth gates land.
  defp initials(nil), do: nil

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

  # No trip readable, nothing to move - the same nothing a stranger's click on the map gets.
  defp write_place(component, _drag, nil), do: idle_drag(component)

  # The hundredths the pin was let go at ARE offsets in a box a hundred wide, so the
  # projection needs no other size - the same trick the ink stroke's points use.
  defp write_place(component, drag, trip) do
    {lat, lng} = Geo.from_offset(drag.x, drag.y, 100, 100, trip.basemap)

    :ok = DB.update(Stop, drag.id, %{lat: lat, lng: lng})

    idle_drag(component)
  end

  defp idle_drag(component) do
    component
    |> put_state(:drag, nil)
    |> put_state(:drag_rect, nil)
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

  # No trip readable, nowhere to put a stop: the click disarms the + and does nothing else,
  # for the same reason `save_stroke/3` drops a stranger's ink.
  defp place(component, _event, nil), do: put_state(component, :placing, false)

  defp place(component, event, trip) do
    {width, height} = component.state.box

    {lat, lng} = Geo.from_offset(event.offset_x, event.offset_y, width, height, trip.basemap)

    {:ok, stop} =
      %{date: trip.starts_on, lat: lat, lng: lng, name: "New stop", trip_id: trip.id}
      |> Stop.new()
      |> DB.create()

    component
    |> put_state(:focused_field, nil)
    |> put_state(:open_stop_id, stop.id)
    |> put_state(:panel_open, true)
    |> put_state(:placing, false)
    |> announce_editing()
  end
end
