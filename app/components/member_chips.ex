defmodule Offgrid.Components.MemberChips do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.User

  @moduledoc """
  The people a trip starts with, added by email.

  The lookup is LOCAL. Every account syncs to every browser, so turning an address into a
  person is a query against the client's own database rather than a question for the server -
  which is what lets a trip be filled in with no network. That is a choice this app makes by
  declaring `allow :read` on User, and an app that would rather not ship its user directory
  writes `allow :read, id: user_id()` instead and gets the same screen back with a round trip
  in it. How offline an app is, is something it declares.

  The typed address is this component's own business and the people chosen are the page's, so
  the input is state here and each pick is handed up.
  """

  prop :invites, [User]
  prop :users, [User], from_query: &users_query/0

  # Both, and they are not the same callback: init/3 is what the SERVER renders the first paint
  # with, init/2 is what the client mounts with. A component holding state needs each - with
  # only the client one, the first render reaches a template whose state does not exist yet.
  def init(_props, component), do: blank(component)

  def init(_props, component, server), do: {blank(component), server}

  def template do
    ~HOLO"""
    <div class="chips">
      {%for invite <- @invites}
        <span class="chip">
          <i class="a"></i>{invite.email}
          <b $click={action: :remove_invite, target: "page", params: %{id: invite.id}}>×</b>
        </span>
      {/for}
    </div>

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

    <p class="note">Members see the trip the moment it is created</p>
    """
  end

  def action(:add, _params, component) do
    add(component, found(component.props.users, component.state.email))
  end

  def action(:edit_email, params, component) do
    put_state(component, :email, params.event.value)
  end

  # An address the app has never seen is the one failure worth naming - anything else and the
  # person is already on the list, which the chips show without a sentence.
  defp blank(component) do
    component
    |> put_state(:email, "")
    |> put_state(:error, nil)
  end

  defp add(component, nil) do
    put_state(component, :error, "Nobody here uses that address.")
  end

  defp add(component, user) do
    component
    |> put_state(:email, "")
    |> put_state(:error, nil)
    |> put_action(name: :add_invite, target: "page", params: %{user: user})
  end

  defp found(users, email) do
    Enum.find(users, &(&1.email == email))
  end

  defp users_query do
    order_by(User, :email)
  end
end
