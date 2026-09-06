defmodule Offgrid.Components.StopEditor do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Components.TripCalendar
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop

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
  Time chips arrive in C9, delete in C10, and real comments in phase G.
  """

  prop :comments, [Comment], from_query: &comments_query/1
  prop :stop, Stop, from_query: &stop_query/1
  prop :stop_id, :string
  prop :trip_id, :string
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
      <div class="ed-sub">{day_label(@stop.date)}</div>

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
            {time_label(time)}
          </button>
        {/for}
      </div>

      <label>Comments</label>
      {%for comment <- @comments}
        <div class="cmt">
          <b><i class={dot_class(comment, @comments, @user_id)}></i>{comment.author.name} · {clock(comment.created_at)}</b>
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
  defp clock(at), do: "#{pad(at.hour)}:#{pad(at.minute)}"

  # The id breaks a tie in the stamp: ids are time-ordered too, and two remarks written in
  # the same millisecond must still come out in the order they were left.
  defp comments_query(stop_id) do
    Comment
    |> filter(stop_id: stop_id)
    |> include(:author)
    |> order_by([:created_at, :id])
  end

  # Your own remarks carry your colour. Everyone else's are coloured by the order they first
  # spoke on this stop - the two the theme names, then the neutral dot for anyone after.
  defp dot_class(comment, comments, user_id) do
    if comment.author_id == user_id do
      "y"
    else
      others =
        comments
        |> Enum.map(& &1.author_id)
        |> Enum.reject(&(&1 == user_id))
        |> Enum.uniq()

      case Enum.find_index(others, &(&1 == comment.author_id)) do
        0 -> "a"
        1 -> "t"
        _later -> "off"
      end
    end
  end

  # A draft typed under another stop is not this stop's.
  defp draft_for(draft, stop_id, stop_id), do: draft

  defp draft_for(_draft, _draft_stop_id, _stop_id), do: ""

  defp day_label(date) do
    "#{weekday(Date.day_of_week(date))} #{date.day} #{month(date.month)}"
  end

  defp month(1), do: "Jan"
  defp month(2), do: "Feb"
  defp month(3), do: "Mar"
  defp month(4), do: "Apr"
  defp month(5), do: "May"
  defp month(6), do: "Jun"
  defp month(7), do: "Jul"
  defp month(8), do: "Aug"
  defp month(9), do: "Sep"
  defp month(10), do: "Oct"
  defp month(11), do: "Nov"
  defp month(12), do: "Dec"

  defp pad(number) when number < 10, do: "0#{number}"

  defp pad(number), do: "#{number}"

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

  defp time_label(time), do: "#{pad(time.hour)}:#{pad(time.minute)}"

  # Half-hourly through the part of the day an itinerary actually uses.
  defp times do
    Enum.map(16..40, fn half_hours ->
      Time.new!(div(half_hours, 2), rem(half_hours, 2) * 30, 0)
    end)
  end

  defp weekday(1), do: "Mon"
  defp weekday(2), do: "Tue"
  defp weekday(3), do: "Wed"
  defp weekday(4), do: "Thu"
  defp weekday(5), do: "Fri"
  defp weekday(6), do: "Sat"
  defp weekday(7), do: "Sun"
end
