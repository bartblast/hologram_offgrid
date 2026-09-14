defmodule Offgrid.Policies.TripMembers do
  @moduledoc """
  The rules for anything that belongs to a trip: whoever is on the trip may read, create,
  update and delete it. An entity taking this policy on must have a `trip` relationship.

  `to: {:trip, :member}` asks whether the actor holds the member role on the referenced trip,
  and organizers count because their role extends member. `via: :trip` would not work: it asks
  the trip about the same operation, and the trip lets everyone create, so anyone could create
  on any trip, while deleting would be left to organizers.
  """

  use Hologram.Policy

  allow :create, to: {:trip, :member}
  allow :delete, to: {:trip, :member}
  allow :read, to: {:trip, :member}
  allow :update, to: {:trip, :member}
end
