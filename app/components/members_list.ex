defmodule Offgrid.Components.MembersList do
  @moduledoc """
  Who is on this trip, read from the role grants themselves - there is no members table. The
  query is filtered by `allow :read_roles` on Trip, and one person can hold several grants, so
  rows collapse to one per person here.

  The browser decides from the grants it holds whether to show the add and remove controls,
  and the server checks the same rules when the write lands. Adding and removing are plain
  actions, and the email lookup is local, as in `MemberChips`, so both work offline.
  """

  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :present, :list, default: []
  prop :trip_id, :string
  prop :user_id, :string
  prop :users, [User], from_query: &users_query/0

  # Mounts when the members popover opens in a page that is already loaded, so it needs init/2.
  def init(_props, component), do: blank(component)

  def template do
    ~HOLO"""
    {%for grant <- one_per_person(@grants)}
      <div class="mrow">
        <i class={dot_class(@grants, @present, @user_id, grant.user_id)}></i>{grant.user.name} <em>{role_label(grant.role)}</em>

        {%if removable?(grant, @user_id, @trip_id)}
          <button
            class="remove"
            type="button"
            aria-label="Remove"
            $click={:remove, user_id: grant.user_id}
          >
            <svg viewBox="0 0 12 12" aria-hidden="true">
              <path d="M3.2 3.2 L8.8 8.8 M8.8 3.2 L3.2 8.8" />
            </svg>
          </button>
        {/if}
      </div>
    {/for}

    {%if may_add?(@user_id, @trip_id)}
      <input
        class="inp"
        placeholder="Add a member by email…"
        value={@email}
        $change={:edit_email}
        $key_down.enter="add"
      />

      {%if @error}
        <p class="err">{@error}</p>
      {/if}
    {/if}
    """
  end

  def action(:add, _params, component) do
    add(component, found(component.props.users, component.state.email))
  end

  def action(:edit_email, params, component) do
    put_state(component, :email, params.event.value)
  end

  # Revokes every role the person holds on the trip, not just the one the row shows.
  def action(:remove, params, component) do
    trip = trip(component.props.trip_id)

    component.props.grants
    |> Enum.filter(&(&1.user_id == params.user_id))
    |> Enum.each(&(:ok = Auth.revoke_role(params.user_id, trip, &1.role)))

    component
  end

  # Oldest first, which puts the trip's creator at the top. The nil beside the id is the
  # type-wide grant, "member of every trip", which the gate counts and this list must too.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> include(:user)
    |> order_by(:created_at)
  end

  # An unknown address is the one failure worth a message. Granting a role somebody already
  # holds keeps the grant they have, so adding twice is not an error.
  defp add(component, nil) do
    put_state(component, :error, "Nobody here uses that address.")
  end

  defp add(component, user) do
    :ok = Auth.grant_role(user, trip(component.props.trip_id), :member)

    blank(component)
  end

  defp blank(component) do
    component
    |> put_state(:email, "")
    |> put_state(:error, nil)
  end

  defp found(users, email) do
    Enum.find(users, &(&1.email == email))
  end

  defp may_add?(user_id, trip_id) do
    Auth.can?(user_id, :grant_role, trip(trip_id))
  end

  # The strongest role each person holds: organizer, which extends member. This only works
  # because Offgrid's roles form a chain.
  defp one_per_person(grants) do
    grants
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
    |> Enum.map(fn user_id ->
      held = Enum.filter(grants, &(&1.user_id == user_id))

      Enum.find(held, &(&1.role == :organizer)) || hd(held)
    end)
  end

  # Somebody else's row, when you may take a role away. Leaving a trip yourself is not offered
  # here.
  defp removable?(grant, user_id, trip_id) do
    grant.user_id != user_id and Auth.can?(user_id, :revoke_role, trip(trip_id))
  end

  # You and anyone else present right now carry their cast colour. Everyone else gets the
  # hollow dot.
  defp dot_class(grants, present, user_id, id) do
    if id == user_id or Enum.any?(present, &(&1.id == id)) do
      Cast.colour(Cast.members(grants), user_id, id)
    else
      "off"
    end
  end

  defp role_label(:member), do: "Member"

  defp role_label(:organizer), do: "Organizer"

  # The gate and the write both name the trip, and neither reads anything off it but its id.
  defp trip(trip_id), do: %Trip{id: trip_id}

  defp users_query, do: order_by(User, :email)
end
