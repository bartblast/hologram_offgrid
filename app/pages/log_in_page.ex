defmodule Offgrid.Pages.LogInPage do
  @moduledoc """
  The card a person logs back in on. The check runs in a command, because the password hash
  never leaves the server.

  A refusal says the same thing whichever half was wrong, so it never confirms that an account
  exists for an address.
  """

  use Hologram.Page
  use Hologram.DB

  alias Hologram.UI.Link
  alias Offgrid.Components.Terrain
  alias Offgrid.Entities.User
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripsPage

  route "/log-in"

  layout Offgrid.Components.DefaultLayout

  middleware Offgrid.Middleware.GuestOnly

  def init(_params, component, _server) do
    put_state(component, email: "", error: nil, password: "")
  end

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <div class="card">
          <h2>Welcome back</h2>
          <p class="sub">Your trips are where you left them.</p>

          <label>Email</label>
          <input
            class="inp"
            id="log_in_email"
            type="email"
            value={@email}
            $change={:edit, field: :email}
            $key_down.enter="log_in"
          />

          <label>Password</label>
          <input
            class="inp"
            id="log_in_password"
            type="password"
            value={@password}
            $change={:edit, field: :password}
            $key_down.enter="log_in"
          />

          {%if @error}
            <p class="err">{@error}</p>
          {/if}

          <button class="btn" type="button" $click="log_in">Log in</button>

          <p class="alt">New here? <Link to={SignUpPage}>Create an account</Link></p>
        </div>
      </div>
    </div>
    """
  end

  def action(:edit, params, component) do
    put_state(component, params.field, params.event.value)
  end

  def action(:log_in, _params, component) do
    component
    |> put_state(:error, nil)
    |> put_command(:log_in, email: component.state.email, password: component.state.password)
  end

  # The server says only that the pair did not match, so one sentence covers both failures.
  def action(:log_in_failed, _params, component) do
    put_state(component, :error, "Wrong email or password.")
  end

  # The trips list rather than a trip, because a trip's page needs one named in its address.
  def action(:logged_in, _params, component) do
    put_page(component, TripsPage)
  end

  def command(:log_in, params, server) do
    user =
      User
      |> filter(email: params.email)
      |> one()
      |> DB.read()

    if verified?(user, params.password) do
      server
      |> put_user_id(user.id)
      |> put_action(:logged_in)
    else
      put_action(server, :log_in_failed)
    end
  end

  # An unknown address still costs a hash comparison, so it takes as long as a wrong password
  # and the timing does not reveal which addresses have accounts.
  defp verified?(nil, _password) do
    Bcrypt.no_user_verify()

    false
  end

  defp verified?(user, password) do
    Bcrypt.verify_pass(password, user.password_hash)
  end
end
