defmodule Offgrid.Entities.Comment do
  @moduledoc """
  A remark left on a stop by somebody on the trip.

  Written once and never edited, so there is no `allow :update` and two browsers can never
  disagree about its text. Changing your mind is a new comment.

  Reading and creating go through the stop, so they are open to members of the trip, and
  creating also pins the author to the actor. Deleting is open to the author, and to anybody
  who may delete the stop: a comment's reference to its stop restricts deletes, so a member
  deleting a stop has to be able to delete the remarks on it first.
  """

  use Hologram.Entity

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.User

  attribute :body, :string

  relationship :author, User
  relationship :stop, Stop

  allow :create, author_id: user_id(), via: :stop
  allow :delete, author_id: user_id()
  allow :delete, via: :stop
  allow :read, via: :stop
end
