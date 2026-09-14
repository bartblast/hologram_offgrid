defmodule Offgrid.Cast do
  @moduledoc """
  One colour per person on a trip, the same wherever that person is drawn.

  You are always your own colour. Everyone else is coloured by the order they joined the trip,
  read from the grant rows oldest first, so whoever made the trip comes first without an order
  being stored: the first other member is violet, the second teal, and anyone after that grey.
  So is anybody no longer on the trip, such as the author of a remark who has since left.
  Colours differ between screens, since "you" differs, but stay stable on each one.
  """

  @doc """
  Returns the class suffix for the given person: "y" for you, "a" for the first other member,
  "t" for the second, "" for anyone else.

  `member_ids` is the trip's members in join order; `you_id` is who is looking, or nil when
  nobody is signed in, in which case everyone is somebody else.
  """
  @spec colour(list(String.t()), String.t() | nil, String.t()) :: String.t()
  def colour(_member_ids, you_id, you_id) when you_id != nil, do: "y"

  def colour(member_ids, you_id, id) do
    case Enum.find_index(member_ids -- [you_id], &(&1 == id)) do
      0 -> "a"
      1 -> "t"
      _later_or_absent -> ""
    end
  end

  @doc """
  Returns the first letter of each of the first two words of the name, upper case: "Nora Vale"
  is "NV".
  """
  @spec initials(String.t()) :: String.t()
  def initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  @doc """
  Returns the ids of the people the given grants name, in join order, each once.

  One person can hold several roles on one trip, so there can be more than one grant row per
  person.
  """
  @spec members(list(struct)) :: list(String.t())
  def members(grants) do
    grants
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
  end
end
