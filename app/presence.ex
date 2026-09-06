defmodule Offgrid.Presence do
  @moduledoc """
  What the trip screen knows about the other people on it right now, and how that changes.

  None of this is a row. Who is here, where their pointer is and what they have open all
  arrive as broadcasts on the trip's channel and live in the page's state until they expire
  or the page goes. These are the pure functions that change that state, kept apart from the
  page so they can be read and tested without a browser.

  Nothing here knows the time. A cursor expires by a sequence number: every position a
  person sends bumps theirs, the page queues a delayed check carrying the number it saw, and
  the check drops the cursor only if no newer position has arrived since. No clock, no
  "leave" event - Hologram has neither a pointer-leave binding nor a disconnect signal - and
  no timer to cancel.

  What somebody has open is stamped the same way, and for a sharper reason: commands are
  asynchronous, so opening a stop and landing in one of its fields - two messages, sent a
  moment apart - can arrive in the other order, and the older one would then wipe the newer
  truth. Each sender counts its own messages and a lower count is ignored. Somebody who has
  closed everything stays in the map with no stop rather than leaving it, because their count
  has to outlive them for the next stale message to be refused.
  """

  @typedoc "Somebody on the screen: their id and the two letters they are drawn as."
  @type person :: %{id: String.t(), initials: String.t()}

  @doc """
  Adds the person to those present, once - somebody already here is not here twice, however
  many times they say so.
  """
  @spec arrive(list(person), person) :: list(person)
  def arrive(present, %{id: id, initials: initials}) do
    if Enum.any?(present, &(&1.id == id)) do
      present
    else
      present ++ [%{id: id, initials: initials}]
    end
  end

  @doc """
  Puts the person's pointer at the given place and returns the cursors with the sequence
  number this position got, which is what `expire/3` later asks about.
  """
  @spec cursor(map, %{id: String.t(), initials: String.t(), x: number, y: number}) ::
          {map, pos_integer}
  def cursor(cursors, %{id: id, initials: initials, x: x, y: y}) do
    seq =
      case cursors do
        %{^id => %{seq: previous}} -> previous + 1
        _none -> 1
      end

    {Map.put(cursors, id, %{initials: initials, seq: seq, x: x, y: y}), seq}
  end

  @doc """
  Records what the person has open: the stop, and the field in it, or nil for either when they
  have closed it.

  Ignored when the sender has already been heard saying something newer - `seq` is their own
  count of the messages they have sent, and a message that lost a race carries a lower one.
  """
  @spec edit(map, %{
          id: String.t(),
          initials: String.t(),
          stop_id: String.t() | nil,
          field: String.t() | nil,
          seq: integer
        }) :: map
  def edit(editing, %{id: id, initials: initials, stop_id: stop_id, field: field, seq: seq}) do
    case editing do
      %{^id => %{seq: heard}} when heard >= seq ->
        editing

      _older_or_unheard ->
        Map.put(editing, id, %{field: field, initials: initials, seq: seq, stop_id: stop_id})
    end
  end

  @doc """
  Drops the person's cursor if the sequence number is still the one given - that is, if no
  newer position has arrived since the check was queued. Otherwise leaves it alone.
  """
  @spec expire(map, String.t(), pos_integer) :: map
  def expire(cursors, id, seq) do
    case cursors do
      %{^id => %{seq: ^seq}} -> Map.delete(cursors, id)
      _newer_or_gone -> cursors
    end
  end

  @doc """
  Returns who has the given field of the given stop focused, in no particular order.
  """
  @spec on_field(map, String.t(), String.t()) :: list(person)
  def on_field(editing, stop_id, field) do
    for {id, %{field: ^field, initials: initials, stop_id: ^stop_id}} <- editing do
      %{id: id, initials: initials}
    end
  end

  @doc """
  Returns who has the given stop open, with the field each of them is in, in no particular
  order.
  """
  @spec on_stop(map, String.t()) ::
          list(%{id: String.t(), initials: String.t(), field: String.t() | nil})
  def on_stop(editing, stop_id) do
    for {id, %{field: field, initials: initials, stop_id: ^stop_id}} <- editing do
      %{field: field, id: id, initials: initials}
    end
  end
end
