defmodule Offgrid.Queries do
  @moduledoc """
  The queries more than one component or page reads, each written once.

  `from_query:` takes a capture of a local function, so a component keeps a one-line `defp`
  that calls in here.
  """

  use Hologram.DB

  alias Hologram.Auth.RoleGrant
  alias Hologram.Query
  alias Offgrid.Entities.Basemap
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User

  @doc """
  Returns the query for every basemap, alphabetical by name.
  """
  @spec basemaps() :: Query.t()
  def basemaps, do: order_by(Basemap, :name)

  @doc """
  Returns the query for the given trip's stops in itinerary order: day, then time, then
  creation. Postgres and the client both sort nulls last, so an untimed stop ends its day.
  """
  @spec itinerary(String.t()) :: Query.t()
  def itinerary(trip_id) do
    Stop
    |> filter(trip_id: trip_id)
    |> order_by([:date, :time, :created_at])
  end

  @doc """
  Returns the query for the grants on the given trip, oldest first, which is the join order
  `Offgrid.Cast` colours people by. A nil entity id is the type-wide "member of every trip"
  grant, which counts as membership too.
  """
  @spec members(String.t()) :: Query.t()
  def members(trip_id) do
    RoleGrant
    |> filter(entity_id: [trip_id, nil], entity_type: Trip)
    |> order_by(:created_at)
  end

  @doc """
  Returns the query for the given trip's stops, in no particular order.
  """
  @spec stops(String.t()) :: Query.t()
  def stops(trip_id), do: filter(Stop, trip_id: trip_id)

  @doc """
  Returns the query for the given trip.
  """
  @spec trip(String.t()) :: Query.t()
  def trip(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> one()
  end

  @doc """
  Returns the query for the given trip together with its basemap.
  """
  @spec trip_with_basemap(String.t()) :: Query.t()
  def trip_with_basemap(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> include(:basemap)
    |> one()
  end

  @doc """
  Returns the query for every user, by email.
  """
  @spec users() :: Query.t()
  def users, do: order_by(User, :email)
end
