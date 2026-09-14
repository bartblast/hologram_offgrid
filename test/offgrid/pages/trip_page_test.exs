defmodule Offgrid.Pages.TripPageTest do
  # The commands ask the trip's grants, and only the feature run boots the database.
  use ExUnit.Case, async: false

  import Offgrid.FeatureHelpers

  alias Hologram.Auth
  alias Hologram.Server
  alias Hologram.Server.Broadcast
  alias Offgrid.Pages.TripPage

  @moduletag :feature

  setup do
    reset_data()

    trip = create_trip()
    user = create_user("Nora Vale", "nora@offgrid.test")

    :ok = Auth.grant_role(user, trip, :member)

    [server: %Server{session_id: "nora-session", user_id: user.id}, trip: trip, user: user]
  end

  describe "command/3" do
    test "announces the signed-in member, not the one the params name", context do
      params = whereabouts(context.trip, id: "forged", initials: "XX")

      assert sender(TripPage.command(:announce, params, context.server)) ==
               {context.user.id, "NV"}
    end

    test "answers as the signed-in member, not the one the params name", context do
      params = whereabouts(context.trip, id: "forged", initials: "XX")

      assert sender(TripPage.command(:answer, params, context.server)) ==
               {context.user.id, "NV"}
    end

    test "tells what the signed-in member has open, not the one the params name", context do
      params = whereabouts(context.trip, id: "forged", initials: "XX")

      assert sender(TripPage.command(:editing, params, context.server)) ==
               {context.user.id, "NV"}
    end
  end

  defp sender(%Server{broadcasts: [%Broadcast{params: params}]}) do
    {params[:id], params[:initials]}
  end

  defp whereabouts(trip, forged) do
    Map.merge(%{field: nil, seq: 1, stop_id: nil, trip_id: trip.id}, Map.new(forged))
  end
end
