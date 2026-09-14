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
  alias Offgrid.Components.TripCalendar
  alias Offgrid.Dates
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop
  alias Offgrid.MemberColor
  alias Offgrid.Presence
  alias Offgrid.Queries
  alias Offgrid.Utils.CSS

  # Half-hourly through the part of the day an itinerary actually uses.
  @times Enum.map(16..40, &Time.new!(div(&1, 2), rem(&1, 2) * 30, 0))

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
    <div class={CSS.class(["editor", away: @away])}>
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

      {%for field <- [:name, :description]}
        <label>{field_label(field)} {%for person <- others_in(@editing, @stop_id, field, @grants, @user_id)}<b class={"tag " <> person.color}>{person.initials}</b>{/for}</label>
        <input
          id={"stop_#{field}"}
          class={CSS.class(["inp", busy: busy?(@editing, @stop_id, field, @user_id)])}
          value={Map.get(@stop, field)}
          $change={:edit, field: field}
          $focus={action: :field_focused, target: "page", params: %{field: field}}
          $blur={action: :field_blurred, target: "page"}
        />
      {/for}

      <label>Day</label>
      <TripCalendar cid="trip_calendar" date={@stop.date} stop_id={@stop_id} trip_id={@trip_id} />

      <label>Time</label>
      <div class="times">
        <button type="button" class={CSS.class(on: same_time?(nil, @stop.time))} $click={:set_time, time: nil}>—</button>

        {%for time <- times()}
          <button type="button" class={CSS.class(on: same_time?(time, @stop.time))} $click={:set_time, time: time}>
            {Dates.time_label(time)}
          </button>
        {/for}
      </div>

      <label>{field_label(:comment)} {%for person <- others_in(@editing, @stop_id, :comment, @grants, @user_id)}<b class={"tag " <> person.color}>{person.initials}</b>{/for}</label>
      {%for remark <- remarks(@comments, @grants, @user_id)}
        <div class="cmt">
          <b><i class={remark.color}></i>{remark.comment.author.name} · {Dates.clock(remark.comment.created_at, @tz_offset)}</b>
          <p>{remark.comment.body}</p>
        </div>
      {/for}
      <input
        id="stop_comment"
        class={CSS.class(["inp", busy: busy?(@editing, @stop_id, :comment, @user_id)])}
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
      %{
        author_id: component.props.user_id,
        body: draft,
        stop_id: component.props.stop_id
      }
      |> Comment.new()
      |> DB.create!()

      put_state(component, :draft, "")
    end
  end

  # Every keystroke is a write, to the client's own database first.
  def action(:edit, params, component) do
    DB.update!(Stop, component.props.stop_id, %{params.field => params.event.value})

    component
  end

  def action(:edit_draft, params, component) do
    put_state(component, draft: params.event.value, draft_stop_id: component.props.stop_id)
  end

  # Clearing the time is as valid as setting one - an untimed stop sinks to the end of its day.
  def action(:set_time, params, component) do
    DB.update!(Stop, component.props.stop_id, %{time: params.time})

    component
  end

  # The input takes a quieter border while somebody else is in it - the tag beside the label
  # says who.
  defp busy?(editing, stop_id, field, user_id) do
    editing
    |> Presence.on_field(stop_id, field)
    |> Enum.any?(&(&1.id != user_id))
  end

  # Ids are time-ordered too, so they break a tie between comments left in the same
  # millisecond.
  defp comments_query(stop_id) do
    Comment
    |> filter(stop_id: stop_id)
    |> include(:author)
    |> order_by([:created_at, :id])
  end

  # A draft typed under another stop is not this stop's.
  defp draft_for(draft, stop_id, stop_id), do: draft

  defp draft_for(_draft, _draft_stop_id, _stop_id), do: ""

  defp field_label(:comment), do: "Comments"

  defp field_label(:description), do: "Description"

  defp field_label(:name), do: "Name"

  defp members_query(trip_id), do: Queries.members(trip_id)

  # Everyone but you with this field of this stop focused, each with their colour.
  defp others_in(editing, stop_id, field, grants, user_id) do
    for person <- Presence.on_field(editing, stop_id, field), person.id != user_id do
      Map.put(person, :color, MemberColor.of(grants, user_id, person.id))
    end
  end

  # Each comment with its author's colour, or the neutral dot for somebody not on the trip.
  defp remarks(comments, grants, user_id) do
    for comment <- comments do
      color =
        case MemberColor.of(grants, user_id, comment.author_id) do
          "" -> "off"
          color -> color
        end

      %{color: color, comment: comment}
    end
  end

  # Time.compare/2 rather than ==: a time read from the database carries microseconds
  # (~T[09:00:00.000000]) and one built here does not, so the structs differ for one moment.
  defp same_time?(nil, nil), do: true

  defp same_time?(nil, _selected), do: false

  defp same_time?(_time, nil), do: false

  defp same_time?(time, selected), do: Time.compare(time, selected) == :eq

  defp stop_query(stop_id) do
    Stop
    |> filter(id: stop_id)
    |> one()
  end

  defp times, do: @times
end
