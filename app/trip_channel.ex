defmodule Offgrid.TripChannel do
  @moduledoc """
  The trip's realtime channel: who may use it, who a message is from, and how a message reaches
  everyone else on the trip.

  Realtime channels do no authorization, and the trip's rules hide rows, not broadcasts, so
  every command that names the channel checks `on_trip?/2` before anything else.
  """

  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.Component
  alias Hologram.Server
  alias Offgrid.Cast
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User
  alias Offgrid.Link

  @doc """
  Returns the initials of the user with the given id, or nil when the account is gone.
  """
  @spec initials(String.t()) :: String.t() | nil
  def initials(user_id) do
    user =
      User
      |> filter(id: user_id)
      |> one()
      |> DB.read()

    if user, do: Cast.initials(user.name)
  end

  @doc """
  Returns whether the session's user may read the trip with the given id, from the grants the
  server holds. A trip the server has not heard of yet answers false.
  """
  @spec on_trip?(Server.t(), String.t()) :: boolean
  def on_trip?(server, trip_id) do
    Auth.can?(server.user_id, :read, %Trip{id: trip_id})
  end

  @doc """
  Broadcasts the given action with the given params to everyone else on the trip's channel,
  and to nobody when the session's user is not on the trip. The sending session is left out,
  since it has already drawn what it sends.
  """
  @spec relay(Server.t(), String.t(), atom, keyword) :: Server.t()
  def relay(server, trip_id, action, params) do
    if on_trip?(server, trip_id) do
      Component.put_broadcast_except(
        server,
        {:session, server.session_id},
        {:trip, trip_id},
        action,
        params
      )
    else
      server
    end
  end

  @doc """
  Returns who a message is from, as the params a presence broadcast carries. Read from the
  session, never from what the browser sent, so no member can speak as another.
  """
  @spec sender(Server.t()) :: keyword
  def sender(server) do
    [id: server.user_id, initials: initials(server.user_id)]
  end

  @doc """
  Queues the given command only while the browser is online. A command that cannot reach the
  server raises, and a ping or a pointer position is not worth an error.
  """
  @spec tell(Component.t(), atom, keyword) :: Component.t()
  def tell(component, command, params) do
    if Link.online?(), do: Component.put_command(component, command, params), else: component
  end
end
