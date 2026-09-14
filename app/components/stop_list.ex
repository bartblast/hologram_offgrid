defmodule Offgrid.Components.StopList do
  @moduledoc """
  The itinerary: every stop of the trip, under the day it happens on.

  The query runs against the client's own database, so a stop written by an action shows up in
  the same frame. Order is never stored, it comes from `Offgrid.Queries.itinerary/1`.
  """

  use Hologram.Component

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Entities.Stop
  alias Offgrid.MemberColor
  alias Offgrid.Presence
  alias Offgrid.Queries
  alias Offgrid.Utils.CSS
  alias Offgrid.Utils.DateFormat

  prop :editing, :map, default: %{}
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :open_stop_id, :string, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip_id, :string
  prop :user_id, :string, default: nil

  def template do
    ~HOLO"""
    {%for day <- days(@stops, @editing, @grants, @user_id)}
      <div class="day">{day_label(day)}</div>

      {%for row <- day}
        <button
          class={CSS.class(["stop", open: row.stop.id == @open_stop_id])}
          type="button"
          $click={action: :open_stop, target: "page", params: %{id: row.stop.id}}
        >
          <span class="stop-name">{row.stop.name}</span>
          <span class="stop-summary">{summary(row.stop)}</span>
          {%for person <- row.people}
            <span class={"sel " <> person.color}><b>{person.initials}</b></span>
          {/for}
        </button>
      {/for}
    {/for}
    """
  end

  # Consecutive runs of stops sharing a date - the query already ordered them. Each stop comes
  # with everyone but you who has it open, drawn as a ring in their colour.
  defp days(stops, editing, grants, user_id) do
    stops
    |> Enum.chunk_by(& &1.date)
    |> Enum.map(fn day ->
      Enum.map(day, &%{people: others_on(editing, &1.id, grants, user_id), stop: &1})
    end)
  end

  defp day_label([row | _rest]), do: DateFormat.day_label(row.stop.date)

  defp members_query(trip_id), do: Queries.members(trip_id)

  defp others_on(editing, stop_id, grants, user_id) do
    for person <- Presence.on_stop(editing, stop_id), person.id != user_id do
      Map.put(person, :color, MemberColor.of(grants, user_id, person.id))
    end
  end

  # Scoped by trip. The policy keeps out trips you are not on, but not your other trips.
  defp stops_query(trip_id), do: Queries.itinerary(trip_id)

  # The second line of a row: the time when there is one, then whatever the stop says
  # about itself.
  defp summary(%Stop{description: nil, time: nil}), do: ""

  defp summary(%Stop{description: description, time: nil}), do: description

  defp summary(%Stop{description: nil, time: time}), do: DateFormat.time_label(time)

  defp summary(%Stop{description: description, time: time}) do
    "#{DateFormat.time_label(time)} · #{description}"
  end
end
