defmodule Offgrid.Components.StopEditor do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Hologram.DB
  alias Offgrid.Cast
  alias Offgrid.Components.TripCalendar
  alias Offgrid.Dates
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip

  @moduledoc """
  The right-hand panel for one stop: what it is called, when it happens, and what
  people have said about it.

  The stop arrives through its own query, bound to the id the page says is open, so the
  panel reads the same local database the list does.

  Name and description write straight to the database as you type - there is no save
  button, because there is nothing to save to. The day comes from the calendar below.

  The remarks under it are their own rows, read by the stop and written by whoever is on the
  trip, and shown in the order they were left.

  The whole panel sits behind `{%if @stop}`, because the stop can go while the panel is open:
  another browser deletes it, the row leaves this browser's database, and the query answers
  nil. The panel renders nothing then rather than dying on a name that is not there. The page
  still holds the id of a stop that is gone, and the next click on the list replaces it.
  """

  prop :comments, [Comment], from_query: &comments_query/1
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :stop, Stop, from_query: &stop_query/1
  prop :stop_id, :string
  prop :trip_id, :string
  prop :tz_offset, :integer, default: 0
  prop :user_id, :string

  # The draft of a remark is the panel's own business, so it is state here - everything else
  # the panel shows is a row. init/2 because the panel appears in a page that is already
  # loaded, the way it does when a stop is clicked.
  #
  # The panel keeps its cid, and so its state, from one stop to the next, so the draft
  # remembers which stop it was typed under and reads as empty under any other.
  def init(_props, component) do
    component
    |> put_state(:draft, "")
    |> put_state(:draft_stop_id, nil)
  end

  def template do
    ~HOLO"""
    {%if @stop}
    <div class="editor">
      <div class="ed-title">{@stop.name}</div>
      <div class="ed-sub">{Dates.day_label(@stop.date)}</div>

      <label>Name</label>
      <input class="inp" value={@stop.name} $change={:edit, field: :name} />

      <label>Description</label>
      <input class="inp" value={@stop.description} $change={:edit, field: :description} />

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

      <label>Comments</label>
      {%for comment <- @comments}
        <div class="cmt">
          <b><i class={dot_class(@grants, @user_id, comment)}></i>{comment.author.name} · {clock(comment.created_at, @tz_offset)}</b>
          <p>{comment.body}</p>
        </div>
      {/for}
      <input
        class="inp"
        placeholder="Add a comment…"
        value={draft_for(@draft, @draft_stop_id, @stop_id)}
        $change={:edit_draft}
        $key_down.enter="add_comment"
      />

      <div class="ed-foot">
        <button
          class="danger"
          type="button"
          $click={action: :delete_stop, target: "page", params: %{id: @stop_id}}
        >Delete stop</button>
      </div>
    </div>
    {/if}
    """
  end

  # Clearing the time is as legitimate as setting one - an untimed stop sinks to the end
  # of its day rather than disappearing.
  # Enter with nothing typed is not a remark. Anything else becomes a row at once - the list
  # above reads the same rows, so it grows in the same frame - and travels afterwards.
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
    component
    |> put_state(:draft, params.event.value)
    |> put_state(:draft_stop_id, component.props.stop_id)
  end

  def action(:set_time, params, component) do
    :ok = DB.update(Stop, component.props.stop_id, %{time: params.time})

    component
  end

  # Every keystroke is a write. It lands in the client's own database first, so the row
  # and this panel agree immediately, and travels afterwards.
  def action(:edit, params, component) do
    :ok = DB.update(Stop, component.props.stop_id, %{params.field => params.event.value})

    component
  end

  # The time the remark was left, as a clock reading rather than "2h ago". A relative time
  # needs a "now", and this browser's now against a stamp another device wrote is not a
  # number worth showing - offline for a day, it would say a comment is from the future.
  #
  # Read as the browser reads it: the row holds UTC, and the page hands down the minutes the
  # browser is behind it. Plain integer arithmetic, wrapped at midnight, rather than a
  # `DateTime` shift whose client port nothing here has checked.
  defp clock(at, offset) do
    minutes = Integer.mod(at.hour * 60 + at.minute - offset, 1_440)

    "#{Dates.pad(div(minutes, 60))}:#{Dates.pad(rem(minutes, 60))}"
  end

  # The id breaks a tie in the stamp: ids are time-ordered too, and two remarks written in
  # the same millisecond must still come out in the order they were left.
  defp comments_query(stop_id) do
    Comment
    |> filter(stop_id: stop_id)
    |> include(:author)
    |> order_by([:created_at, :id])
  end

  # Each remark carries its author's colour - the one the cast gives them everywhere else on
  # the screen. Somebody who is no longer on the trip, or never was, gets the neutral dot.
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

  # A draft typed under another stop is not this stop's.
  defp draft_for(draft, stop_id, stop_id), do: draft

  defp draft_for(_draft, _draft_stop_id, _stop_id), do: ""

  defp stop_query(stop_id) do
    Stop
    |> filter(id: stop_id)
    |> one()
  end

  # Time.compare/2 rather than a pattern match or ==: a time read back from the database
  # carries microsecond precision (~T[09:00:00.000000]) while a time built here does not
  # (~T[09:00:00]), so the two structs differ while naming the same moment.
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
