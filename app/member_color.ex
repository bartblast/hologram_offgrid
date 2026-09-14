defmodule Offgrid.MemberColor do
  @moduledoc """
  One colour per person on a trip, the same wherever that person is drawn: a face, a cursor, a
  ring on a stop, a remark.

  You are always your own colour. Everyone else is coloured by the order they joined the trip,
  read from the grant rows oldest first, so whoever made the trip comes first without an order
  being stored: the first other member is violet, the second teal, and anyone after that grey.
  So is anybody no longer on the trip, such as the author of a remark who has since left.
  Colours differ between screens, since "you" differs, but stay stable on each one.
  """

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Entities.User

  @doc """
  Returns the class suffix for the given person: "y" for you, "a" for the first other member,
  "t" for the second, "" for anyone else.

  `members` is the trip's grants oldest first, where one person can hold several, or for a trip
  not made yet, the invited users in the order they were added. `viewer_id` is who is looking,
  or nil when nobody is signed in, in which case everyone is somebody else.
  """
  @spec of(list(RoleGrant.t() | User.t()), String.t() | nil, String.t()) :: String.t()
  def of(_members, viewer_id, viewer_id) when viewer_id != nil, do: "y"

  def of(members, viewer_id, person_id) do
    others =
      members
      |> Enum.map(&id_of/1)
      |> Enum.uniq()
      |> List.delete(viewer_id)

    case Enum.find_index(others, &(&1 == person_id)) do
      0 -> "a"
      1 -> "t"
      _later_or_absent -> ""
    end
  end

  defp id_of(%RoleGrant{user_id: id}), do: id

  defp id_of(%User{id: id}), do: id
end
