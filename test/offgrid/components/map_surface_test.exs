defmodule Offgrid.Components.MapSurfaceTest do
  # The command asks the trip's grants, and only the feature run boots the database.
  use ExUnit.Case, async: false

  import Offgrid.FeatureHelpers

  alias Hologram.Auth
  alias Hologram.Server
  alias Hologram.Server.Broadcast
  alias Offgrid.Components.MapSurface

  @moduletag :feature

  setup do
    reset_data()

    trip = create_trip()
    user = create_user("Nora Vale", "nora@offgrid.test")

    :ok = Auth.grant_role(user, trip, :member)

    [server: %Server{session_id: "nora-session", user_id: user.id}, trip: trip, user: user]
  end

  describe "command/3" do
    test "moves the signed-in member's cursor, not the one the params name", context do
      params = %{id: "forged", initials: "XX", trip_id: context.trip.id, x: 10.0, y: 20.0}

      assert %Server{broadcasts: [%Broadcast{params: broadcast}]} =
               MapSurface.command(:cursor, params, context.server)

      assert {broadcast[:id], broadcast[:initials]} == {context.user.id, "NV"}
    end
  end
end
