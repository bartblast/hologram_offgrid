defmodule Offgrid.Entities.Sketch do
  use Hologram.Entity

  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User

  attribute :color, :string
  attribute :points, :string

  relationship :author, User
  relationship :trip, Trip

  @moduledoc """
  A line somebody drew over the trip's map.

  A stroke is written once and never edited, the same as a comment: it is finished the moment
  the pointer lifts, so there is nothing an update could mean and no way two browsers can
  disagree about a line. Rubbing something out is deleting a row.

  `points` is the whole stroke in one string, "lat,lng lat,lng ...", in the same real
  coordinates the stops use - so a sketch survives the map being resized, and moves with the
  map when the trip changes basemap. It is stored and drawn and never queried or sorted,
  which is why one string is honest here where it would be laziness on anything the app
  asks questions about.

  The rules go through the trip rather than a stop, because ink belongs to the map: you may
  draw on a trip exactly when you may add a stop to it. Creating pins the author to the actor.

  Rubbing out is your own line, or anybody's if you organize the trip - the two delete lines
  are read as one or the other. A member cannot clear somebody else's ink, and an organizer
  can, because a map nobody may tidy fills up.
  """

  allow :create, author_id: user_id(), via: :trip
  allow :delete, author_id: user_id()
  allow :delete, to: {:trip, :organizer}
  allow :read, via: :trip
end
