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

  One person can hold several roles on one trip - the creator of a trip they were invited to
  holds both - so the store answers a row per grant and the collapsing to a row per person
  happens here.
  """

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :trip_id, :string

  # The list holds no state of its own - it renders what the query answers. This exists
  # because a stateful component appearing on an already-loaded page must have init/2, and
  # the list appears exactly that way once the popover opens.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    {%for grant <- one_per_person(@grants)}
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

  # The strongest role each person holds, which for Offgrid means organizer over member, since
  # organizer extends it. This is the app's answer and not the framework's: "strongest" is only
  # well-defined where an app's roles form a chain, and two roles neither of which extends the
  # other have no order to pick by.
  defp one_per_person(grants) do
    grants
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.map(fn user_id ->
      held = Enum.filter(grants, &(&1.user_id == user_id))

      Enum.find(held, &(&1.role == :organizer)) || hd(held)
    end)
  end

  defp role_label(:member), do: "Member"

  defp role_label(:organizer), do: "Organizer"
end
