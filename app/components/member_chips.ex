defmodule Offgrid.Components.MemberChips do
  @moduledoc """
  The people a new trip starts with: a chip for each one invited, and the field to add another.
  The page holds the invites, so each pick and each removal goes to the page.
  """

  use Hologram.Component

  alias Offgrid.Components.MemberInput
  alias Offgrid.Entities.User
  alias Offgrid.MemberColor

  prop :invites, [User]

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

    <MemberInput cid="member_input" on_add={:add_invite} target="page" />

    <p class="note">Members see the trip the moment it is created</p>
    """
  end

  # There is no trip yet to take a join order from, so invites are coloured in the order they
  # were added, which is the order they will join in.
  defp chip_class(invites, invite), do: MemberColor.of(invites, nil, invite.id)
end
