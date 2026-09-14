defmodule Offgrid.Trips do
  @moduledoc """
  Deleting a stop or a whole trip, together with everything that points at it.

  References restrict rather than cascade, so a row can go only after the rows that name it:
  comments before their stop, stops and ink before their trip. Called from an action, the
  deletes reach the server as one batch, so nobody watching sees a trip half gone.
  """

  use Hologram.DB

  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip

  @doc """
  Deletes the stop with the given id and the comments on it.
  """
  @spec delete_stop(String.t()) :: :ok
  def delete_stop(stop_id) do
    Comment
    |> filter(stop_id: stop_id)
    |> DB.read()
    |> Enum.each(&DB.delete!(Comment, &1.id))

    DB.delete!(Stop, stop_id)
  end

  @doc """
  Deletes the trip with the given id, its stops with their comments, and its ink.
  """
  @spec delete_trip(String.t()) :: :ok
  def delete_trip(trip_id) do
    Stop
    |> filter(trip_id: trip_id)
    |> DB.read()
    |> Enum.each(&delete_stop(&1.id))

    Sketch
    |> filter(trip_id: trip_id)
    |> DB.read()
    |> Enum.each(&DB.delete!(Sketch, &1.id))

    DB.delete!(Trip, trip_id)
  end
end
