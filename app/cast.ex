defmodule Offgrid.Cast do
  @moduledoc """
  One colour per person on a trip, the same wherever that person is drawn.

  The theme names three colours for people: yours, and two for the others. Who gets which is
  decided once, here, from the order people joined the trip - the grant rows, oldest first,
  which puts whoever made the trip at the head without storing an order anywhere. Faces,
  remark dots, member rows, chips, cursors and editing marks all ask this module, so a person
  is one colour on a screen and stays it tomorrow.

  You are always your own colour. Everyone else is coloured by their place among the others:
  the first is violet, the second teal, anyone after that grey - and so is anybody not on the
  trip at all, such as somebody whose remark outlived their membership. The colours differ
  from one person's screen to another's, since "you" moves, and that is what the eye needs:
  stable on the screen in front of it.
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
  Returns the first letter of each of the first two words of the name, upper case - "Nora
  Vale" is "NV" - which is what a face is.
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

  One person can hold several roles on one trip, so the store answers a row per grant and the
  collapsing to one id per person happens here.
  """
  @spec members(list(struct)) :: list(String.t())
  def members(grants) do
    grants
    |> Enum.map(& &1.user_id)
    |> Enum.uniq()
  end
end
