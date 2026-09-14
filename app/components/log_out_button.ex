defmodule Offgrid.Components.LogOutButton do
  @moduledoc """
  The button that ends the session and returns to the log-in card. Logging out is a command,
  because only the server can write the session.
  """

  use Hologram.Component

  alias Offgrid.Pages.LogInPage

  def template do
    ~HOLO"""
    <button class="signout" type="button" $click={command: :log_out}>Log out</button>
    """
  end

  def action(:logged_out, _params, component) do
    put_page(component, LogInPage)
  end

  def command(:log_out, _params, server) do
    server
    |> delete_user_id()
    |> put_action(:logged_out)
  end
end
