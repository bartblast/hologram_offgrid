defmodule Offgrid.Components.TripDetails do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Dates
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.TripsPage

  @moduledoc """
  The trip's own card: what it is called and when it runs.

  Every keystroke is a write, the way the stop editor's are. The row lands in the client's
  database first, so the panel header behind this card renames itself in the same frame -
  two components reading one row, with no message passing between them and no network.

  The map and the people are not here, though the mockup drew them in this card. Each grew a
  home of its own on the screen behind it, and a second copy of either would be a second place
  to look rather than a convenience.

  Deleting takes everything on the trip with it, innermost first: the remarks on each stop,
  the ink, the stops, then the trip. Every reference is required and the framework's foreign
  keys restrict rather than cascade, so a trip with anything on it cannot simply go - and a
  batch the server refuses is rolled back by the browser without a word, so the trip would
  quietly be back. Innermost first is also the only order that reads correctly to another
  browser watching: nobody ever sees a remark on no stop, or a stop on no trip.
  """

  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string
  prop :user_id, :string

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

        {%if deletable?(@user_id, @trip_id)}
          <div class="ed-foot">
            <button class="danger" type="button" $click="delete">Delete trip</button>
          </div>
        {/if}
      </div>
    {/if}
    """
  end

  # Innermost first, then away - one batch, so a browser watching never sees a trip whose
  # itinerary has already gone. The remarks and the ink are read here rather than carried as
  # props: they are needed once, on the way out.
  def action(:delete, _params, component) do
    trip_id = component.props.trip_id

    Enum.each(component.props.stops, fn stop ->
      Comment
      |> filter(stop_id: stop.id)
      |> DB.read()
      |> Enum.each(&(:ok = DB.delete(Comment, &1.id)))
    end)

    Sketch
    |> filter(trip_id: trip_id)
    |> DB.read()
    |> Enum.each(&(:ok = DB.delete(Sketch, &1.id)))

    Enum.each(component.props.stops, &(:ok = DB.delete(Stop, &1.id)))

    :ok = DB.delete(Trip, trip_id)

    put_page(component, TripsPage)
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

  # Organizers only, which the browser answers from the grants it holds - the same question the
  # server asks again when the batch lands.
  defp deletable?(user_id, trip_id) do
    Auth.can?(user_id, :delete, %Trip{id: trip_id})
  end

  defp stops_query(trip_id) do
    filter(Stop, trip_id: trip_id)
  end

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> one()
  end

  defp write_date(component, _field, nil), do: component

  # A date moved past the other takes the other with it, so a trip is never backwards and
  # nobody is told to edit the other field first. One write either way - two fields when the
  # dates would have crossed, one when they would not.
  defp write_date(component, field, date) do
    :ok =
      DB.update(Trip, component.props.trip_id, date_changes(component.props.trip, field, date))

    component
  end

  defp date_changes(trip, :starts_on, date) do
    if Date.compare(date, trip.ends_on) == :gt,
      do: %{ends_on: date, starts_on: date},
      else: %{starts_on: date}
  end

  defp date_changes(trip, :ends_on, date) do
    if Date.compare(date, trip.starts_on) == :lt,
      do: %{ends_on: date, starts_on: date},
      else: %{ends_on: date}
  end
end
