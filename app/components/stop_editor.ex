defmodule Offgrid.Components.StopEditor do
  @moduledoc """
  The right-hand panel for one stop: its name, description, day, time and comments. Name and
  description are written to the database as you type, so there is no save button.

  Another browser can delete the stop while the panel is open, so the content sits behind
  `{%if @stop}`. The box itself shows for `@stop || @away`, so a stop deleted from this panel
  still slides out after its row is gone.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Components.TripCalendar
  alias Offgrid.Dates
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Presence

  prop :away, :boolean, default: false
  prop :comments, [Comment], from_query: &comments_query/1
  prop :editing, :map, default: %{}
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :stop, Stop, from_query: &stop_query/1
  prop :stop_id, :string
  prop :trip_id, :string
  prop :tz_offset, :integer, default: 0
  prop :user_id, :string

  # Mounts in a page that is already loaded, so it needs init/2. The panel keeps its state from
  # one stop to the next, so the comment draft remembers which stop it was typed under.
  def init(_props, component) do
    put_state(component, draft: "", draft_stop_id: nil)
  end

  def template do
    ~HOLO"""
    {%if @stop || @away}
    <div class={editor_class(@away)}>
      {%if @stop}
      <div class="ed-head">
        <div>
          <div class="ed-title">{@stop.name}</div>
          <div class="ed-sub">{Dates.day_label(@stop.date)}</div>
        </div>

        <button
          class="ed-close"
          type="button"
          aria-label="Close"
          $click={action: :close_stop, target: "page"}
        >
          <svg viewBox="0 0 12 12" aria-hidden="true">
            <path d="M3.2 3.2 L8.8 8.8 M8.8 3.2 L3.2 8.8" />
          </svg>
        </button>
      </div>

      <label>Name {%for person <- others_in(@editing, @stop_id, :name, @user_id)}<b class={tag_class(@grants, @user_id, person.id)}>{person.initials}</b>{/for}</label>
      <input
        id="stop_name"
        class={field_class(@editing, @stop_id, :name, @user_id)}
        value={@stop.name}
        $change={:edit, field: :name}
        $focus={action: :field_focused, target: "page", params: %{field: :name}}
        $blur={action: :field_blurred, target: "page"}
      />

      <label>Description {%for person <- others_in(@editing, @stop_id, :description, @user_id)}<b class={tag_class(@grants, @user_id, person.id)}>{person.initials}</b>{/for}</label>
      <input
        id="stop_description"
        class={field_class(@editing, @stop_id, :description, @user_id)}
        value={@stop.description}
        $change={:edit, field: :description}
        $focus={action: :field_focused, target: "page", params: %{field: :description}}
        $blur={action: :field_blurred, target: "page"}
      />

      <label>Day</label>
      <TripCalendar cid="trip_calendar" date={@stop.date} stop_id={@stop_id} trip_id={@trip_id} />

      <label>Time</label>
      <div class="times">
        <button type="button" class={time_class(nil, @stop.time)} $click={:set_time, time: nil}>—</button>

        {%for time <- times()}
          <button type="button" class={time_class(time, @stop.time)} $click={:set_time, time: time}>
            {Dates.time_label(time)}
          </button>
        {/for}
      </div>

      <label>Comments {%for person <- others_in(@editing, @stop_id, :comment, @user_id)}<b class={tag_class(@grants, @user_id, person.id)}>{person.initials}</b>{/for}</label>
      {%for comment <- @comments}
        <div class="cmt">
          <b><i class={dot_class(@grants, @user_id, comment)}></i>{comment.author.name} · {clock(comment.created_at, @tz_offset)}</b>
          <p>{comment.body}</p>
        </div>
      {/for}
      <input
        id="stop_comment"
        class={field_class(@editing, @stop_id, :comment, @user_id)}
        placeholder="Add a comment…"
        value={draft_for(@draft, @draft_stop_id, @stop_id)}
        $change={:edit_draft}
        $key_down.enter="add_comment"
        $focus={action: :field_focused, target: "page", params: %{field: :comment}}
        $blur={action: :field_blurred, target: "page"}
      />

      <div class="ed-foot">
        <button
          class="danger"
          type="button"
          $click={action: :delete_stop, target: "page", params: %{id: @stop_id}}
        >Delete stop</button>
      </div>
      {/if}
    </div>
    {/if}
    """
  end

  # Enter with nothing typed adds no comment.
  def action(:add_comment, _params, component) do
    state = component.state
    draft = draft_for(state.draft, state.draft_stop_id, component.props.stop_id)

    if String.trim(draft) == "" do
      component
    else
      {:ok, _comment} =
        %{
          author_id: component.props.user_id,
          body: draft,
          stop_id: component.props.stop_id
        }
        |> Comment.new()
        |> DB.create()

      put_state(component, :draft, "")
    end
  end

  def action(:edit_draft, params, component) do
    put_state(component, draft: params.event.value, draft_stop_id: component.props.stop_id)
  end

  # Clearing the time is as valid as setting one - an untimed stop sinks to the end of its day.
  def action(:set_time, params, component) do
    :ok = DB.update(Stop, component.props.stop_id, %{time: params.time})

    component
  end

  # Every keystroke is a write, to the client's own database first.
  def action(:edit, params, component) do
    :ok = DB.update(Stop, component.props.stop_id, %{params.field => params.event.value})

    component
  end

  # A clock reading rather than "2h ago", because this browser's clock against a stamp from
  # another device is not reliable. The row holds UTC and the page passes the browser's offset
  # in minutes, applied with integer arithmetic rather than a `DateTime` shift.
  defp clock(at, offset) do
    minutes = Integer.mod(at.hour * 60 + at.minute - offset, 1_440)

    "#{Dates.pad(div(minutes, 60))}:#{Dates.pad(rem(minutes, 60))}"
  end

  # Ids are time-ordered too, so they break a tie between comments left in the same
  # millisecond.
  defp comments_query(stop_id) do
    Comment
    |> filter(stop_id: stop_id)
    |> include(:author)
    |> order_by([:created_at, :id])
  end

  # The author's cast colour, or the neutral dot for somebody not on the trip.
  defp dot_class(grants, user_id, comment) do
    case Cast.colour(Cast.members(grants), user_id, comment.author_id) do
      "" -> "off"
      colour -> colour
    end
  end

  # The trip's members in join order, for the cast - the same rows the members list reads.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> order_by(:created_at)
  end

  # The input takes a quieter border while somebody else is in it - the tag beside the label
  # says who.
  defp field_class(editing, stop_id, field, user_id) do
    if others_in(editing, stop_id, field, user_id) == [], do: "inp", else: "inp busy"
  end

  # Everyone but you with this field of this stop focused.
  defp others_in(editing, stop_id, field, user_id) do
    editing
    |> Presence.on_field(stop_id, field)
    |> Enum.reject(&(&1.id == user_id))
  end

  defp tag_class(grants, user_id, id) do
    "tag " <> Cast.colour(Cast.members(grants), user_id, id)
  end

  # Slides off to the right while leaving. The page keeps the stop until the slide ends.
  defp editor_class(true), do: "editor away"

  defp editor_class(false), do: "editor"

  # A draft typed under another stop is not this stop's.
  defp draft_for(draft, stop_id, stop_id), do: draft

  defp draft_for(_draft, _draft_stop_id, _stop_id), do: ""

  defp stop_query(stop_id) do
    Stop
    |> filter(id: stop_id)
    |> one()
  end

  # Time.compare/2 rather than ==: a time read from the database carries microseconds
  # (~T[09:00:00.000000]) and one built here does not, so the structs differ for one moment.
  defp time_class(nil, nil), do: "on"

  defp time_class(nil, _selected), do: nil

  defp time_class(_time, nil), do: nil

  defp time_class(time, selected) do
    if Time.compare(time, selected) == :eq, do: "on"
  end

  # Half-hourly through the part of the day an itinerary actually uses.
  defp times do
    Enum.map(16..40, fn half_hours ->
      Time.new!(div(half_hours, 2), rem(half_hours, 2) * 30, 0)
    end)
  end
end
