defmodule Offgrid.Components.Faces do
  @moduledoc """
  Who is here, as a row of faces: everyone else the page knows is present, then you.

  The page keeps who is present in its state, from broadcasts. This component adds each face's
  `Offgrid.Cast` colour, which needs the trip's member list, and only a component can hold a
  query.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :present, :list
  prop :trip_id, :string
  prop :user_id, :string
  prop :you, :string

  def template do
    ~HOLO"""
    {%for face <- @present}
      <div class={face_class(@grants, @user_id, face)}>{face.initials}</div>
    {/for}

    <div class="face y">{@you}</div>
    """
  end

  defp face_class(grants, user_id, face) do
    "face " <> Cast.colour(Cast.members(grants), user_id, face.id)
  end

  # The same grants the members list reads, in the same order.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> order_by(:created_at)
  end
end
