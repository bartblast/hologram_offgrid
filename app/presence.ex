defmodule Offgrid.Presence do
  @moduledoc """
  What the trip screen knows about the other people on it right now: who is here, where their
  pointer is and what they have open. None of it is a row. It arrives as broadcasts on the
  trip's channel and lives in page state, and these pure functions change that state.

  The app gets no leave or disconnect signal, so it infers departure from silence: everyone
  says they are still here on a timer, and anyone not heard from for a few turns is dropped.

  Nothing here reads a clock. Each cursor carries a sequence number that every new position
  bumps. The page queues a delayed check with the number it saw, and the check drops the cursor
  only if no newer position has arrived since.

  What somebody has open is guarded by a count too. Commands are asynchronous, so two messages
  sent a moment apart can arrive in the other order. Each sender counts its own messages and a
  lower count is ignored. Somebody who has closed everything stays in the map with no stop, so
  their count is still there to refuse the next stale message.
  """

  @typedoc "Somebody on the screen: their id and the two letters they are drawn as."
  @type person :: %{id: String.t(), initials: String.t() | nil}

  @typedoc "Everyone else's pointer, by person id, with the sequence number of its newest position."
  @type cursors :: %{
          String.t() => %{initials: String.t(), seq: pos_integer, x: number, y: number}
        }

  @typedoc "What everyone else has open, by person id, with the count of their newest message."
  @type editing :: %{
          String.t() => %{
            field: atom | nil,
            initials: String.t(),
            seq: integer,
            stop_id: String.t() | nil
          }
        }

  @doc """
  Adds the person to those present, once, however many times they say they are here.
  """
  @spec arrive(list(person), %{
          :id => String.t(),
          :initials => String.t() | nil,
          optional(atom) => term
        }) ::
          list(person)
  def arrive(present, %{id: id, initials: initials}) do
    if Enum.any?(present, &(&1.id == id)) do
      present
    else
      # Arrival order, and the list is a handful of people long.
      # credo:disable-for-next-line Credo.Check.Refactor.AppendSingleItem
      present ++ [%{id: id, initials: initials}]
    end
  end

  @doc """
  Puts the person's pointer at the given place and returns the cursors with the sequence
  number this position got, which is what `expire/3` later asks about.
  """
  @spec cursor(cursors, %{
          :id => String.t(),
          :initials => String.t() | nil,
          :x => number,
          :y => number,
          optional(atom) => term
        }) ::
          {cursors, pos_integer}
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
  count of the messages they have sent.
  """
  @spec edit(editing, %{
          :id => String.t(),
          :initials => String.t() | nil,
          :stop_id => String.t() | nil,
          :field => atom | nil,
          :seq => integer,
          optional(atom) => term
        }) :: editing
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
  @spec expire(cursors, String.t(), pos_integer) :: cursors
  def expire(cursors, id, seq) do
    case cursors do
      %{^id => %{seq: ^seq}} -> Map.delete(cursors, id)
      _newer_or_gone -> cursors
    end
  end

  @doc """
  Drops the person's face and whatever they had open, but only if nothing newer has been heard
  from them since the check was queued.
  """
  @spec depart(list(person), editing, String.t(), integer) :: {list(person), editing}
  def depart(present, editing, id, seq) do
    case editing do
      %{^id => %{seq: ^seq}} ->
        {Enum.reject(present, &(&1.id == id)), Map.delete(editing, id)}

      _newer_or_gone ->
        {present, editing}
    end
  end

  @doc """
  Returns who has the given field of the given stop focused, in no particular order.
  """
  @spec on_field(editing, String.t(), atom) :: list(person)
  def on_field(editing, stop_id, field) do
    for {id, %{field: ^field, initials: initials, stop_id: ^stop_id}} <- editing do
      %{id: id, initials: initials}
    end
  end

  @doc """
  Returns who has the given stop open, with the field each of them is in, in no particular
  order.
  """
  @spec on_stop(editing, String.t()) ::
          list(%{id: String.t(), initials: String.t(), field: atom | nil})
  def on_stop(editing, stop_id) do
    for {id, %{field: field, initials: initials, stop_id: ^stop_id}} <- editing do
      %{field: field, id: id, initials: initials}
    end
  end
end
