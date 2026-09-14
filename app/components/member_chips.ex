defmodule Offgrid.Components.MemberChips do
  @moduledoc """
  The people a new trip starts with, added by email.

  `User` declares `allow :read`, so every account syncs to the browser and an address becomes a
  person without the network. The typed address is state here, and each pick is handed up to
  the page, which holds the invites.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Cast
  alias Offgrid.Entities.User

  prop :invites, [User]
  prop :users, [User], from_query: &users_query/0

  # The page always renders this, so it is initialized on the server with init/3.
  def init(_props, component, _server), do: blank(component)

  def template do
    ~HOLO"""
    <div class="chips">
      {%for invite <- @invites}
        <span class="chip">
          <i class={chip_class(@invites, invite)}></i>{invite.email}
          <button
            type="button"
            aria-label="Remove"
            $click={action: :remove_invite, target: "page", params: %{id: invite.id}}
          >×</button>
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

  # There is no trip yet to take a join order from, so invites are coloured in the order they
  # were added, which is the order they will join in.
  defp chip_class(invites, invite) do
    Cast.colour(Enum.map(invites, & &1.id), nil, invite.id)
  end

  defp blank(component) do
    put_state(component, email: "", error: nil)
  end

  # An unknown address is the one failure worth a message. The page ignores a person already
  # invited, and the chips already show them.
  defp add(component, nil) do
    put_state(component, :error, "Nobody here uses that address.")
  end

  defp add(component, user) do
    component
    |> blank()
    |> put_action(name: :add_invite, target: "page", params: %{user: user})
  end

  defp found(users, email) do
    Enum.find(users, &(&1.email == email))
  end

  defp users_query do
    order_by(User, :email)
  end
end
