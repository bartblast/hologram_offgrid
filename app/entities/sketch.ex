defmodule Offgrid.Entities.Sketch do
  @moduledoc """
  A line somebody drew over the trip's map.

  Written once when the pointer lifts and never edited, like a comment. Rubbing a line out
  deletes the row.

  `path` is an SVG path string built by `Offgrid.Stroke.path/1` from `{lng, -lat}` points.
  `Offgrid.Components.Ink` uses it directly as the `d` attribute inside a `viewBox` set to the
  basemap's bounds, so the line is drawn without any projection. It is only stored and drawn,
  never queried, which is why one string is enough.

  Reading goes through the trip, and creating pins the author to the actor. A line may be
  deleted by its author or by an organizer of the trip, so somebody can always tidy the map.
  """

  use Hologram.Entity

  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User

  attribute :color, :string
  attribute :path, :string

  relationship :author, User
  relationship :trip, Trip

  allow :create, author_id: user_id(), to: {:trip, :member}
  allow :delete, author_id: user_id()
  allow :delete, to: {:trip, :organizer}
  allow :read, via: :trip
end
