defmodule Offgrid.Entities.Comment do
  use Hologram.Entity

  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.User

  attribute :body, :string

  relationship :author, User
  relationship :stop, Stop

  @moduledoc """
  A remark left on a stop by somebody on the trip.

  Written once and never edited - a comment is a create-and-delete row, so two browsers can
  never disagree about its text, and there is no `allow :update` because there is nothing an
  update could honestly mean. Changing your mind is a new comment.

  `via: :stop` hands the question to the stop, whose own rules ask the trip: you may read or
  leave a comment here exactly when you may read or add a stop here, which is when you are on
  the trip. The comment declares no role of its own because it has no membership of its own.
  Creating also pins the author to the actor, so a comment cannot be signed by somebody else.

  Deleting is the author's, or anybody's who may delete the stop - which is every member,
  since a stop is theirs to throw away together with everything said about it. The second
  line is what lets a member delete a stop somebody else remarked on: a remark names its
  stop and the reference restricts, so the remarks have to go first, and a rule that
  protected a remark more strongly than the stop under it left such a stop deletable by
  nobody at all.
  """

  allow :create, author_id: user_id(), via: :stop
  allow :delete, author_id: user_id()
  allow :delete, via: :stop
  allow :read, via: :stop
end
