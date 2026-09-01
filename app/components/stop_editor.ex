defmodule Offgrid.Components.StopEditor do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Stop

  @moduledoc """
  The right-hand panel for one stop: what it is called, when it happens, and what
  people have said about it.

  The stop arrives through its own query, bound to the id the page says is open, so the
  panel reads the same local database the list does.

  The fields do not write anything back yet: editable name and description come in C7,
  the day calendar in C8, the time chips in C9, delete in C10, and real comments in
  phase G.
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
      <input class="inp" value={@stop.name} />

      <label>Description</label>
      <input class="inp" value={@stop.description} />

      <label>Day</label>
      <div class="cal">
        <button type="button"><span class="dw">Sat</span><span class="nm">28</span><span class="dt"><i></i><i></i></span></button>
        <button type="button"><span class="dw">Sun</span><span class="nm">29</span><span class="dt"></span></button>
        <button type="button" class="on"><span class="dw">Mon</span><span class="nm">30</span><span class="dt"><i></i></span></button>
        <button type="button"><span class="dw">Tue</span><span class="nm">31</span><span class="dt"></span></button>
        <button type="button"><span class="dw">Wed</span><span class="nm">1</span><span class="dt"><i></i></span></button>
        <button type="button"><span class="dw">Thu</span><span class="nm">2</span><span class="dt"></span></button>
        <button type="button"><span class="dw">Fri</span><span class="nm">3</span><span class="dt"></span></button>
        <button type="button"><span class="dw">Sat</span><span class="nm">4</span><span class="dt"></span></button>
        <button type="button"><span class="dw">Sun</span><span class="nm">5</span><span class="dt"></span></button>
        <button type="button"><span class="dw">Mon</span><span class="nm">6</span><span class="dt"></span></button>
      </div>

      <label>Time</label>
      <div class="times">
        <button type="button">—</button>
        <button type="button">10:00</button>
        <button type="button">10:30</button>
        <button type="button" class="on">11:00</button>
        <button type="button">11:30</button>
        <button type="button">12:00</button>
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
        <button class="danger" type="button">Delete stop</button>
      </div>
    </div>
    """
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

  defp stop_query(stop_id) do
    Stop
    |> filter(id: stop_id)
    |> one()
  end

  defp weekday(1), do: "Mon"
  defp weekday(2), do: "Tue"
  defp weekday(3), do: "Wed"
  defp weekday(4), do: "Thu"
  defp weekday(5), do: "Fri"
  defp weekday(6), do: "Sat"
  defp weekday(7), do: "Sun"
end
