defmodule Offgrid.Components.MembersList do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth.RoleGrant

  @moduledoc """
  Who is on this trip, read from the grants themselves.

  There is no members table - a membership IS a grant of a role on the trip, so the list is a
  query over the grant store with the person each one names pulled in beside it. That is why
  adding someone later is one write and not two.

  What the query returns is already filtered by `allow :read_roles` on Trip: a member sees the
  whole list, and somebody with no role on the trip sees nothing, without this component
  asking who is looking.
  """

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :trip_id, :string

  def template do
    ~HOLO"""
    {%for grant <- @grants}
      <div class="mrow">
        <i class="off"></i>{grant.user.name} <em>{role_label(grant.role)}</em>
      </div>
    {/for}
    """
  end

  # Oldest first, which puts whoever made the trip at the top without storing an order - they
  # hold the creator's grant, written in the same breath as the trip.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(resource_id: trip_id)
    |> include(:user)
    |> order_by(:created_at)
  end

  defp role_label(:member), do: "Member"

  defp role_label(:organizer), do: "Organizer"
end
