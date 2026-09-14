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

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Queries

  prop :cursors, :map
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :trip_id, :string
  prop :user_id, :string

  def template do
    ~HOLO"""
    {%for cursor <- others(@cursors, @grants, @user_id)}
      <div class={"cursor " <> cursor.color} style={"left:#{cursor.x}%;top:#{cursor.y}%"}>
        <svg class="cur" viewBox="0 0 12 18" aria-hidden="true">
          <path d="M1 1 L1 15.2 L4.6 11.7 L7 16.9 L9.5 15.8 L7.1 10.7 L11.6 10.4 Z" />
        </svg>
        <b><i></i>{cursor.initials}</b>
      </div>
    {/for}
    """
  end

  defp members_query(trip_id), do: Queries.members(trip_id)

  # Everyone but you, each with their id and colour.
  defp others(cursors, grants, user_id) do
    members = Cast.members(grants)

    for {id, cursor} <- cursors, id != user_id do
      Map.merge(cursor, %{color: Cast.color(members, user_id, id), id: id})
    end
  end
end
