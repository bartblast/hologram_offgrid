defmodule Offgrid.Policies.TripMembers do
  use Hologram.Policy

  @moduledoc """
  The rules of anything that belongs to a trip, written once.

  A policy is a set of `allow` lines an entity type takes on with one `policy` line, as if it
  had written them itself. This one says a single sentence: whoever is on the trip may see
  what is on it, add to it, change it and remove it.

  `to: {:trip, :member}` asks whether the acting user holds the member role on the row this
  entity's `trip` reference names - per row, so a member of another trip gets nothing. An
  organizer counts, because the organizer role extends member. The entity type taking this
  on has to declare that `trip` relationship, which is what makes the four lines mean the
  same thing wherever they land.

  Why not `via: :trip`, which reads shorter: that delegates the SAME operation to the trip,
  and the trip grants nobody `:create` and only organizers `:delete`, so creating a stop
  would refuse everyone and deleting one would refuse every member. The member role is the
  thing to ask about, and this is where it is asked.
  """

  # Whoever is on the trip may see what is on it, add to it, change it and remove it.
  # Written once, taken on by every entity type that belongs to a trip.
  allow :create, to: {:trip, :member}
  allow :delete, to: {:trip, :member}
  allow :read, to: {:trip, :member}
  allow :update, to: {:trip, :member}
end
