defmodule Offgrid.Components.MemberInput do
  @moduledoc """
  An email field that turns an address into a person.

  `User` declares `allow :read`, so every account is in the browser's database and the lookup
  needs no network. A person found is handed to the `on_add` action on `target` as
  `%{user: user}`. An unknown address is the one failure worth a message.
  """

  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.User

  prop :on_add, :atom, required: true
  prop :target, :string, required: true
  prop :users, [User], from_query: &users_query/0

  # Rendered with the new trip form on the server, and in the members popover on the client.
  def init(_props, component, _server), do: blank(component)

  def init(_props, component), do: blank(component)

  def template do
    ~HOLO"""
    <input
      class="inp"
      id="member_email"
      placeholder="Add a member by email…"
      value={@email}
      $change={:edit_email}
      $key_down.enter="add"
    />

    {%if @error}
      <p class="err">{@error}</p>
    {/if}
    """
  end

  def action(:add, _params, component) do
    case Enum.find(component.props.users, &(&1.email == component.state.email)) do
      nil ->
        put_state(component, :error, "Nobody here uses that address.")

      user ->
        component
        |> blank()
        |> put_action(
          name: component.props.on_add,
          target: component.props.target,
          params: %{user: user}
        )
    end
  end

  def action(:edit_email, params, component) do
    put_state(component, :email, params.event.value)
  end

  defp blank(component), do: put_state(component, email: "", error: nil)

  defp users_query, do: order_by(User, :email)
end
