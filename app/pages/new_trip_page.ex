defmodule Offgrid.Pages.NewTripPage do
  use Hologram.Page
  use Hologram.DB

  alias Offgrid.Components.BasemapPicker
  alias Offgrid.Components.Terrain
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.TripsPage

  @moduledoc """
  Where a trip begins.

  The whole form lives in page state and the trip is written by an ACTION, not a command,
  which is the point: a create is a client write like any other, so it lands in the
  browser's own database first and travels afterwards. Starting a trip works with no
  network, and the person who started it sees it immediately - before the server has been
  told, and before the organizer grant that write will earn them exists.

  Dates arrive from the browser's own date control as "2026-03-28", which is picked apart
  here rather than parsed: `Date.from_iso8601!/1` is not among the functions that reach the
  client, and splitting three integers is the same work without the dependency.
  """

  route "/trips/new"

  layout Offgrid.DefaultLayout

  def init(_params, component, _server) do
    component
    |> put_state(:basemap_id, nil)
    |> put_state(:ends_on, "")
    |> put_state(:error, nil)
    |> put_state(:name, "")
    |> put_state(:starts_on, "")
  end

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <div class="card wide">
          <h2>New trip</h2>
          <p class="sub">Name it, pick a map, bring your people.</p>

          <label>Name</label>
          <input class="inp" value={@name} $change={:edit, field: :name} />

          <div class="pair">
            <div>
              <label>Starts</label>
              <input
                class="inp"
                id="starts_on"
                type="date"
                value={@starts_on}
                $change={:edit, field: :starts_on}
              />
            </div>
            <div>
              <label>Ends</label>
              <input
                class="inp"
                id="ends_on"
                type="date"
                value={@ends_on}
                $change={:edit, field: :ends_on}
              />
            </div>
          </div>

          <label>Map</label>
          <BasemapPicker cid="basemap_picker" selected_id={@basemap_id} />

          {%if @error}
            <p class="err">{@error}</p>
          {/if}

          <button class="btn" type="button" $click="create">Create trip</button>
        </div>
      </div>
    </div>
    """
  end

  def action(:create, _params, component) do
    state = component.state

    ends_on = to_date(state.ends_on)
    starts_on = to_date(state.starts_on)

    create(component, state, starts_on, ends_on)
  end

  def action(:edit, params, component) do
    put_state(component, params.field, params.event.value)
  end

  def action(:pick_basemap, params, component) do
    put_state(component, :basemap_id, params.id)
  end

  # Everything the row needs, said in the order the form asks for it, so the message names
  # the field the person should look at next rather than the first one that happens to fail.
  defp create(component, %{name: ""}, _starts_on, _ends_on) do
    put_state(component, :error, "Give the trip a name.")
  end

  defp create(component, _state, nil, _ends_on) do
    put_state(component, :error, "Pick the day it starts.")
  end

  defp create(component, _state, _starts_on, nil) do
    put_state(component, :error, "Pick the day it ends.")
  end

  defp create(component, %{basemap_id: nil}, _starts_on, _ends_on) do
    put_state(component, :error, "Pick a map.")
  end

  defp create(component, state, starts_on, ends_on) do
    {:ok, _trip} =
      %{
        basemap_id: state.basemap_id,
        ends_on: ends_on,
        name: state.name,
        starts_on: starts_on
      }
      |> Trip.new()
      |> DB.create()

    # Back to the list, where the new trip is already the top row. TODO: open the trip
    # itself once a trip has an address to open - today every trip answers at "/", so
    # "the trip you just made" is not a thing this page can navigate to.
    put_page(component, TripsPage)
  end

  defp to_date(value) do
    case String.split(value, "-") do
      [year, month, day] ->
        Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))

      _other ->
        nil
    end
  end
end
