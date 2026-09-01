defmodule Offgrid.Components.StopEditor do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Components.TripCalendar
  alias Offgrid.Entities.Stop

  @moduledoc """
  The right-hand panel for one stop: what it is called, when it happens, and what
  people have said about it.

  The stop arrives through its own query, bound to the id the page says is open, so the
  panel reads the same local database the list does.

  Name and description write straight to the database as you type - there is no save
  button, because there is nothing to save to. The day comes from the calendar below.
  Time chips arrive in C9, delete in C10, and real comments in phase G.
  """

  prop :stop, Stop, from_query: &stop_query/1
  prop :stop_id, :string

  # The panel holds no state of its own - it renders what the page says is open. This
  # exists because a stateful component appearing on an already-loaded page must have
  # init/2, and the panel appears exactly that way when a stop is clicked.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    <div class="editor">
      <div class="ed-title">{@stop.name}</div>
      <div class="ed-sub">{day_label(@stop.date)}</div>

      <label>Name</label>
      <input class="inp" value={@stop.name} $change={:edit, field: :name} />

      <label>Description</label>
      <input class="inp" value={@stop.description} $change={:edit, field: :description} />

      <label>Day</label>
      <TripCalendar cid="trip_calendar" date={@stop.date} stop_id={@stop_id} />

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
      <div class="cmt">
        <b><i class="t"></i>Tom · 2h ago</b>
        <p>Onsen booked. Dinner is not, someone call them before Friday</p>
      </div>
      <div class="cmt">
        <b><i class="a"></i>Anna · 1h ago</b>
        <p>I can call tomorrow morning</p>
      </div>
      <input class="inp" placeholder="Add a comment…" />

      <div class="ed-foot">
        <button
          class="danger"
          type="button"
          $click={action: :delete_stop, target: "page", params: %{id: @stop_id}}
        >Delete stop</button>
      </div>
    </div>
    """
  end

  # Clearing the time is as legitimate as setting one - an untimed stop sinks to the end
  # of its day rather than disappearing.
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
