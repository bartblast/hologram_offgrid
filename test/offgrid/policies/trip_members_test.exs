defmodule Offgrid.Policies.TripMembersTest do
  use ExUnit.Case, async: true

  alias Offgrid.Policies.TripMembers

  # The four lines, as the policy hands them to whoever takes it on: one sentence four times,
  # every operation gated on the member role of the row's trip.
  test "declares the four member rules" do
    assert TripMembers.__declarations__() == [
             {:allow, :create, [to: {:trip, :member}]},
             {:allow, :delete, [to: {:trip, :member}]},
             {:allow, :read, [to: {:trip, :member}]},
             {:allow, :update, [to: {:trip, :member}]}
           ]
  end
end
