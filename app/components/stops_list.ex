defmodule Offgrid.Components.StopsList do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Dates
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Presence

  @moduledoc """
  The itinerary: every stop of the trip, under the day it happens on.

  The stops arrive as a registered query the client evaluates against its own database,
  so a stop written by an action shows up here in the same frame - before anything has
  been sent anywhere.

  Order is derived, never stored: day, then time, then when the row was created. A stop
  with no time sinks to the end of its day, which both tiers agree on - Postgres sorts
  nulls last ascending, and so does the client's query kernel.
  """

  prop :editing, :map, default: %{}
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :open_stop_id, :string, default: nil
  prop :stops, [Stop], from_query: &stops_query/1
  prop :trip_id, :string
  prop :user_id, :string, default: nil

  def template do
    ~HOLO"""
    {%for day <- days(@stops)}
      <div class="day">{day_label(day)}</div>

      {%for stop <- day}
        <div class={row_class(stop, @open_stop_id)} $click={action: :open_stop, target: "page", params: %{id: stop.id}}>
          <h4>{stop.name}</h4>
          <p>{summary(stop)}</p>
          {%for person <- others_on(@editing, stop.id, @user_id)}
            <div class={sel_class(@grants, @user_id, person.id)}><b>{person.initials}</b></div>
          {/for}
        </div>
      {/for}
    {/for}
    """
  end

  # Consecutive runs of stops sharing a date. The query already ordered them, so chunking
  # preserves that order and never re-sorts.
  defp days(stops) do
    Enum.chunk_by(stops, & &1.date)
  end

  defp day_label([stop | _rest]), do: Dates.day_label(stop.date)

  defp row_class(%Stop{id: id}, id), do: "stop open"

  defp row_class(_stop, _open_stop_id), do: "stop"

  # The trip's members in join order, for the cast.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> order_by(:created_at)
  end

  # Everyone but you who has this stop open. A ring around the row, in their colour, with
  # their letters on it - the mockup's own mark for "somebody is here".
  defp others_on(editing, stop_id, user_id) do
    editing
    |> Presence.on_stop(stop_id)
    |> Enum.reject(&(&1.id == user_id))
  end

  defp sel_class(grants, user_id, id) do
    "sel " <> Cast.colour(Cast.members(grants), user_id, id)
  end

  # Scoped by trip, now that a screen is one trip's. The policy would already keep another
  # person's stops out, but it would not keep out the ones on YOUR other trips - membership is
  # what it answers, not which trip is on screen.
  defp stops_query(trip_id) do
    Stop
    |> filter(trip_id: trip_id)
    |> order_by([:date, :time, :created_at])
  end

  # The second line of a row: the time when there is one, then whatever the stop says
  # about itself.
  defp summary(%Stop{description: nil, time: nil}), do: ""

  defp summary(%Stop{description: description, time: nil}), do: description

  defp summary(%Stop{description: nil, time: time}), do: Dates.time_label(time)

  defp summary(%Stop{description: description, time: time}) do
    "#{Dates.time_label(time)} · #{description}"
  end
end
