defmodule Offgrid.Components.Faces do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip

  @moduledoc """
  Who is here, as a row of faces: everyone the page has seen this session, then you.

  The list of who is here belongs to the page - it is a broadcast, not a row - and arrives
  as a prop. What this component adds is the colour: each face takes the one `Offgrid.Cast`
  gives that person, which needs the trip's member list, and a member list is a query, which
  only a component can hold. That is the whole reason the faces are not markup on the page.
  """

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :present, :list
  prop :trip_id, :string
  prop :user_id, :string
  prop :you, :string, default: nil

  def template do
    ~HOLO"""
    {%for face <- @present}
      <div class={face_class(@grants, @user_id, face)}>{face.initials}</div>
    {/for}

    {%if @you}
      <div class="face y">{@you}</div>
    {/if}
    """
  end

  defp face_class(grants, user_id, face) do
    "face " <> Cast.colour(Cast.members(grants), user_id, face.id)
  end

  # The same grants the members list reads, in the same order: oldest first, with the
  # type-wide "member of every trip" beside the trip's own.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> order_by(:created_at)
  end
end
