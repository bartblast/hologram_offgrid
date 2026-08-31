defmodule Offgrid.Components.StopEditor do
  use Hologram.Component

  @moduledoc """
  The right-hand panel for one stop: what it is called, when it happens, and what
  people have said about it.

  Static for now - every value below is hardcoded to the mockup's Ryokan stop. Phase C
  replaces them field by field: real values in C5, editable name and description in C7,
  the day calendar in C8, the time chips in C9, delete in C10, and comments in phase G.
  """

  def template do
    ~HOLO"""
    <div class="editor">
      <div class="ed-title">Ryokan</div>
      <div class="ed-sub">Mon 30 Mar</div>

      <label>Name</label>
      <input class="inp" value="Ryokan" />

      <label>Description</label>
      <input class="inp" value="Two nights in Hakone, onsen on site" />

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
end
