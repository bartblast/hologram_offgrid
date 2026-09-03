defmodule Offgrid.Components.TripDetails do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Dates
  alias Offgrid.Entities.Trip

  @moduledoc """
  The trip's own card: what it is called and when it runs.

  Every keystroke is a write, the way the stop editor's are. The row lands in the client's
  database first, so the panel header behind this card renames itself in the same frame -
  two components reading one row, with no message passing between them and no network.

  The map and the people are not here, though the mockup drew them in this card. Each grew a
  home of its own on the screen behind it, and a second copy of either would be a second place
  to look rather than a convenience.
  """

  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string

  # init/2, because the card appears in a page that is already loaded.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    {%if @trip}
      <div class="scrim" $click={action: :close_details, target: "page"}></div>

      <div class="card wide">
        <h2>{@trip.name}</h2>
        <p class="sub">Trip details</p>

        <label>Name</label>
        <input class="inp" value={@trip.name} $change={:edit, field: :name} />

        <div class="pair">
          <div>
            <label>Starts</label>
            <input
              class="inp"
              id="details_starts_on"
              type="date"
              value={date_value(@trip.starts_on)}
              $change={:edit_date, field: :starts_on}
            />
          </div>

          <div>
            <label>Ends</label>
            <input
              class="inp"
              id="details_ends_on"
              type="date"
              value={date_value(@trip.ends_on)}
              $change={:edit_date, field: :ends_on}
            />
          </div>
        </div>
      </div>
    {/if}
    """
  end

  def action(:edit, params, component) do
    :ok = DB.update(Trip, component.props.trip_id, %{params.field => params.event.value})

    component
  end

  # A half-typed date is a date the input has not finished spelling, not a date to store. The
  # control emits one on the way to every complete one, so writing it would empty the field
  # under the person filling it in.
  def action(:edit_date, params, component) do
    write_date(component, params.field, Dates.parse(params.event.value))
  end

  defp date_value(date), do: Dates.to_input(date)

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> one()
  end

  defp write_date(component, _field, nil), do: component

  defp write_date(component, field, date) do
    :ok = DB.update(Trip, component.props.trip_id, %{field => date})

    component
  end
end
