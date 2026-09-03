defmodule Offgrid.Pages.NewTripPage do
  use Hologram.Page
  use Hologram.DB

  alias Hologram.Auth
  alias Offgrid.Components.BasemapPicker
  alias Offgrid.Components.MemberChips
  alias Offgrid.Components.Terrain
  alias Offgrid.Dates
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.TripsPage

  @moduledoc """
  Where a trip begins.

  The whole form lives in page state and the trip is written by an ACTION, not a command,
  which is the point: a create is a client write like any other, so it lands in the
  browser's own database first and travels afterwards. Starting a trip works with no
  network, and the person who started it sees it immediately - before the server has been
  told, and before the organizer grant that write will earn them exists.

  The people invited are granted their membership in the same action, which works for the
  same reason: a grant is a client write too, and the organizer grant the create earns rides
  in that create's own batch. So a trip can be named, mapped, filled with people and started
  on a plane, and the whole thing lands as one when the network comes back.

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
    |> put_state(:invites, [])
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

          <label>Members</label>
          <MemberChips cid="member_chips" invites={@invites} />

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

    ends_on = Dates.parse(state.ends_on)
    starts_on = Dates.parse(state.starts_on)

    create(component, state, starts_on, ends_on)
  end

  def action(:add_invite, params, component) do
    invites = component.state.invites

    if Enum.any?(invites, &(&1.id == params.user.id)) do
      component
    else
      put_state(component, :invites, invites ++ [params.user])
    end
  end

  def action(:edit, params, component) do
    put_state(component, params.field, params.event.value)
  end

  def action(:pick_basemap, params, component) do
    put_state(component, :basemap_id, params.id)
  end

  def action(:remove_invite, params, component) do
    invites = Enum.reject(component.state.invites, &(&1.id == params.id))

    put_state(component, :invites, invites)
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
    {:ok, trip} =
      %{
        basemap_id: state.basemap_id,
        ends_on: ends_on,
        name: state.name,
        starts_on: starts_on
      }
      |> Trip.new()
      |> DB.create()

    # The create wrote the organizer grant this needs, into the same batch, so the browser
    # already knows whose trip it is - which is what lets a trip be started and filled in
    # with nobody watching.
    Enum.each(state.invites, &(:ok = Auth.grant_role(&1, trip, :member)))

    # Back to the list, where the new trip is already the top row. TODO: open the trip
    # itself once a trip has an address to open - today every trip answers at "/", so
    # "the trip you just made" is not a thing this page can navigate to.
    put_page(component, TripsPage)
  end
end
