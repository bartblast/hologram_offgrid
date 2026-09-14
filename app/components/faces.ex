defmodule Offgrid.Components.Faces do
  @moduledoc """
  Who is here, as a row of faces: everyone else the page knows is present, then you.

  The page keeps who is present in its state, from broadcasts. This component adds each face's
  `Offgrid.Cast` colour, which needs the trip's member list, and only a component can hold a
  query.
  """

  use Hologram.Component

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Queries

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :present, :list
  prop :trip_id, :string
  prop :user_id, :string
  prop :you, :string

  def template do
    ~HOLO"""
    {%for face <- faces(@present, @grants, @user_id)}
      <div class={"face " <> face.colour}>{face.initials}</div>
    {/for}

    <div class="face y">{@you}</div>
    """
  end

  defp faces(present, grants, user_id) do
    members = Cast.members(grants)

    Enum.map(present, &Map.put(&1, :colour, Cast.colour(members, user_id, &1.id)))
  end

  defp members_query(trip_id), do: Queries.members(trip_id)
end
