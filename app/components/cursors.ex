defmodule Offgrid.Components.Cursors do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip

  @moduledoc """
  Where everyone else's pointer is on the map, as a dot with their initials.

  The positions belong to the page - they are broadcasts, kept in its state until they fade -
  and arrive as a prop, as a share of the map's width and height, so a cursor lands on the
  same place whatever size the map is drawn at. What this component adds is the colour, the
  one `Offgrid.Cast` gives the person, which needs the trip's member list, and a member list
  is a query, which only a component can hold.

  Your own pointer is not here. It is the real one, under your hand.

  A cursor that stops moving fades: the page drops a position two and a half seconds after
  nothing newer has arrived, which is what a pointer that left the map, or stopped over the
  panel, looks like from another screen. There is no leave event to say so.
  """

  prop :cursors, :map
  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :trip_id, :string
  prop :user_id, :string

  def template do
    ~HOLO"""
    {%for cursor <- others(@cursors, @user_id)}
      <div class={cursor_class(@grants, @user_id, cursor.id)} style={"left:#{cursor.x}%;top:#{cursor.y}%"}>
        <i></i><b>{cursor.initials}</b>
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
