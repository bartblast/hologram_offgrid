defmodule Offgrid.Components.MembersList do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.Auth.RoleGrant
  alias Offgrid.Entities.Trip

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

  Whether the remove controls are drawn at all is a question the browser answers for itself,
  from the grants it already holds. Nobody is asked, and the answer is the same one the server
  gives when the write lands.
  """

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :trip_id, :string
  prop :user_id, :string

  # The list holds no state of its own - it renders what the query answers. This exists
  # because a stateful component appearing on an already-loaded page must have init/2, and
  # the list appears exactly that way once the popover opens.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    {%for grant <- one_per_person(@grants)}
      <div class="mrow">
        <i class="off"></i>{grant.user.name} <em>{role_label(grant.role)}</em>

        {%if removable?(grant, @user_id, @trip_id)}
          <u $click={:remove, user_id: grant.user_id}>×</u>
        {/if}
      </div>
    {/for}
    """
  end

  # Removing somebody means they hold NO role on the trip afterwards, so every grant of theirs
  # goes and not just the one the row happens to show. A plain write, so it lands in the local
  # database and the row leaves the list before anything travels.
  def action(:remove, params, component) do
    trip = trip(component.props.trip_id)

    component.props.grants
    |> Enum.filter(&(&1.user_id == params.user_id))
    |> Enum.each(&(:ok = Auth.revoke_role(params.user_id, trip, &1.role)))

    component
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

  # Somebody else's row, and only when this browser's user may take a role away. Your own row
  # carries no cross - leaving a trip is a different act from removing a person, and it is not
  # in this panel.
  defp removable?(grant, user_id, trip_id) do
    grant.user_id != user_id and Auth.can?(user_id, :revoke_role, trip(trip_id))
  end

  defp role_label(:member), do: "Member"

  defp role_label(:organizer), do: "Organizer"

  # The gate and the write both name the trip, and neither reads anything off it but its id.
  defp trip(trip_id), do: %Trip{id: trip_id}
end
