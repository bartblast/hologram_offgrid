defmodule Offgrid.Pages.NewTripPage do
  @moduledoc """
  The form a trip begins on.

  The form lives in page state, and the trip and its members' grants are written by an action,
  not a command. Both are client writes that land in the browser's database first, so a trip
  can be created offline and reaches the server as one batch when the network returns.
  """

  use Hologram.Page
  use Hologram.DB

  alias Hologram.Auth
  alias Offgrid.Components.BasemapPicker
  alias Offgrid.Components.MemberChips
  alias Offgrid.Components.Terrain
  alias Offgrid.Dates
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.TripPage

  route "/trips/new"

  layout Offgrid.DefaultLayout

  middleware Offgrid.Middleware.RequireSession

  def init(_params, component, _server) do
    put_state(component,
      basemap_id: nil,
      ends_on: "",
      error: nil,
      invites: [],
      name: "",
      starts_on: ""
    )
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

  # Checked in the order the form asks for the fields, so the message names the next one to fix.
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

  # `Date.compare/2` cannot sit in a guard, so the date order is checked in a body.
  defp create(component, state, starts_on, ends_on) do
    if Date.compare(ends_on, starts_on) == :lt do
      put_state(component, :error, "It cannot end before it starts.")
    else
      start(component, state, starts_on, ends_on)
    end
  end

  defp start(component, state, starts_on, ends_on) do
    {:ok, trip} =
      %{
        basemap_id: state.basemap_id,
        ends_on: ends_on,
        name: state.name,
        starts_on: starts_on
      }
      |> Trip.new()
      |> DB.create()

    # The create wrote the organizer grant these need into the same batch, so the browser
    # already knows whose trip it is.
    Enum.each(state.invites, &(:ok = Auth.grant_role(&1, trip, :member)))

    # The server may not have the trip yet, but the trip screen reads the same local rows, so
    # there is nothing to wait for.
    put_page(component, TripPage, id: trip.id)
  end
end
