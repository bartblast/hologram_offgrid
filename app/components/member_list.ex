defmodule Offgrid.Components.MemberList do
  @moduledoc """
  Who is on this trip, read from the role grants themselves - there is no members table. The
  query is filtered by `allow :read_roles` on Trip, and one person can hold several grants, so
  rows collapse to one per person here.

  The browser decides from the grants it holds whether to show the add and remove controls,
  and the server checks the same rules when the write lands. Adding and removing are plain
  actions, and the email lookup is local, so both work offline.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.Auth.RoleGrant
  alias Offgrid.Components.MemberInput
  alias Offgrid.Entities.Trip
  alias Offgrid.MemberColor
  alias Offgrid.Queries

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :present, :list, default: []
  prop :trip_id, :string
  prop :user_id, :string

  # Mounts when the members popover opens in a page that is already loaded, so it needs init/2.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    {%for row <- rows(@grants, @present, @user_id, @trip_id)}
      <div class="mrow">
        <i class={row.color}></i>{row.grant.user.name} <em>{role_label(row.grant.role)}</em>

        {%if row.removable}
          <button
            class="remove"
            type="button"
            aria-label="Remove"
            $click={:remove, user_id: row.grant.user_id}
          >
            <svg viewBox="0 0 12 12" aria-hidden="true">
              <path d="M3.2 3.2 L8.8 8.8 M8.8 3.2 L3.2 8.8" />
            </svg>
          </button>
        {/if}
      </div>
    {/for}

    {%if Auth.can?(@user_id, :grant_role, trip(@trip_id))}
      <MemberInput cid="member_input" on_add={:add} target={@cid} />
    {/if}
    """
  end

  # Granting a role somebody already holds keeps the grant they have, so adding twice is not an
  # error.
  def action(:add, params, component) do
    Auth.grant_role(params.user, trip(component.props.trip_id), :member)

    component
  end

  # Revokes every role the person holds on the trip, not just the one the row shows.
  def action(:remove, params, component) do
    trip = trip(component.props.trip_id)

    component.props.grants
    |> Enum.filter(&(&1.user_id == params.user_id))
    |> Enum.each(&Auth.revoke_role(params.user_id, trip, &1.role))

    component
  end

  defp members_query(trip_id) do
    trip_id
    |> Queries.members()
    |> include(:user)
  end

  defp role_label(:member), do: "Member"

  defp role_label(:organizer), do: "Organizer"

  # One row per person, in join order, with the strongest role they hold: organizer, which
  # extends member - this only works because Offgrid's roles form a chain. You and anyone
  # present right now carry your colour, and everyone else the hollow dot. Only somebody else's
  # row can be removed, and only by someone who may revoke roles.
  defp rows(grants, present, user_id, trip_id) do
    may_remove = Auth.can?(user_id, :revoke_role, trip(trip_id))

    strongest =
      Enum.reduce(grants, %{}, fn grant, acc ->
        Map.update(acc, grant.user_id, grant, &stronger(&1, grant))
      end)

    for %{user_id: id} <- Enum.uniq_by(grants, & &1.user_id) do
      here = id == user_id or Enum.any?(present, &(&1.id == id))

      color =
        if here do
          MemberColor.of(grants, user_id, id)
        else
          "off"
        end

      %{
        color: color,
        grant: Map.fetch!(strongest, id),
        removable: may_remove and id != user_id
      }
    end
  end

  defp stronger(%{role: :organizer} = held, _grant), do: held

  defp stronger(_held, %{role: :organizer} = grant), do: grant

  defp stronger(held, _grant), do: held

  # The gate and the write both name the trip, and neither reads anything off it but its id.
  defp trip(trip_id), do: %Trip{id: trip_id}
end
