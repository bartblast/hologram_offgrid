defmodule Offgrid.Components.MembersList do
  use Hologram.Component
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.Auth.RoleGrant
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User

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

  Whether the controls for changing the list are drawn at all is a question the browser answers
  for itself, from the grants it already holds. Nobody is asked, and the answer is the same one
  the server gives when the write lands.

  Adding is by email and the lookup is LOCAL, the way `MemberChips` does it when a trip is
  first made: every account syncs to every browser, so turning an address into a person needs
  no network. Both changing verbs are plain actions, which is what puts membership on the
  offline side of the line.
  """

  prop :grants, [RoleGrant], from_query: &members_query/1
  prop :present, :list, default: []
  prop :trip_id, :string
  prop :user_id, :string
  prop :users, [User], from_query: &users_query/0

  # The typed address is this component's own business, so it is state here. init/2 rather than
  # init/3 because the list appears in a page that is ALREADY loaded, the way the stop editor
  # does - the popover opening is what mounts it, on the client.
  def init(_props, component), do: blank(component)

  def template do
    ~HOLO"""
    {%for grant <- one_per_person(@grants)}
      <div class="mrow">
        <i class={dot_class(@grants, @present, @user_id, grant.user_id)}></i>{grant.user.name} <em>{role_label(grant.role)}</em>

        {%if removable?(grant, @user_id, @trip_id)}
          <u $click={:remove, user_id: grant.user_id}>×</u>
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
  # hold the creator's grant, written in the same breath as the trip. The nil beside the id is
  # the type-wide grant, "member of every trip", which the gate counts and this list must too.
  defp members_query(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> include(:user)
    |> order_by(:created_at)
  end

  # An address the app has never seen is the one failure worth naming - anything else and the
  # person is already in the list above, which says it without a sentence. Granting a role
  # somebody already holds keeps the grant they have, so adding twice is not an error either.
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

  # Somebody on the screen right now - you, or anyone the page has seen this session - carries
  # their cast colour. Anyone else gets the hollow dot: on the trip, not here.
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
