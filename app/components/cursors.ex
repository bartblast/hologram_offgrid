defmodule Offgrid.Components.Cursors do
  @moduledoc """
  Where everyone else's pointer is on the map, as a dot with their initials. Your own pointer
  is not drawn.

  The positions are broadcasts the page keeps in its state, as percentages of the map so a
  cursor lands in the same place at any size, and drops once nothing newer arrives. This
  component adds each person's `Offgrid.Cast` colour, which needs the trip's member list, and
  only a component can hold a query.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip

  prop :cursors, :map
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :trip_id, :string
  prop :user_id, :string

  def template do
    ~HOLO"""
    {%for cursor <- others(@cursors, @user_id)}
      <div class={cursor_class(@grants, @user_id, cursor.id)} style={"left:#{cursor.x}%;top:#{cursor.y}%"}>
        <svg class="cur" viewBox="0 0 12 18" aria-hidden="true">
          <path d="M1 1 L1 15.2 L4.6 11.7 L7 16.9 L9.5 15.8 L7.1 10.7 L11.6 10.4 Z" />
        </svg>
        <b><i></i>{cursor.initials}</b>
      </div>
    {/for}
    """
  end

  defp cursor_class(grants, user_id, id) do
    "cursor " <> Cast.colour(Cast.members(grants), user_id, id)
  end

  # The same grants the members list reads, in the same order.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> order_by(:created_at)
  end

  # Everyone but you, as a list the template can walk, each entry carrying its id.
  defp others(cursors, user_id) do
    for {id, cursor} <- cursors, id != user_id do
      Map.put(cursor, :id, id)
    end
  end
end
