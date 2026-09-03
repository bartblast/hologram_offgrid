defmodule Offgrid.Pages.LogInPage do
  use Hologram.Page
  use Hologram.DB

  alias Hologram.UI.Link
  alias Offgrid.Components.Terrain
  alias Offgrid.Entities.User
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripsPage

  @moduledoc """
  The card a person comes back through.

  The whole exchange happens in the command: the browser sends what was typed, the server
  finds the account and compares the password against the stored hash. A hash never leaves
  the server, so the comparison cannot happen anywhere else - which is the one place in
  this app where doing the work locally would be wrong rather than merely slower.

  A refusal says the same thing whichever half was wrong. Telling someone the address was
  right but the password was not confirms that an account exists, which is worth more to
  someone guessing than it is to whoever mistyped.
  """

  route "/log-in"

  layout Offgrid.DefaultLayout

  def init(_params, component, _server) do
    component
    |> put_state(:email, "")
    |> put_state(:error, nil)
    |> put_state(:password, "")
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
          <input class="inp" type="email" value={@email} $change={:edit, field: :email} />

          <label>Password</label>
          <input class="inp" type="password" value={@password} $change={:edit, field: :password} />

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

  # The message is the page's rather than the server's: the server says only that the pair
  # did not match, and one sentence covers both ways it can fail.
  def action(:log_in_failed, _params, component) do
    put_state(component, :error, "Wrong email or password.")
  end

  # The trips list rather than a trip: which trip a person wants is theirs to say, and after
  # this commit a trip's page needs one named in its address.
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

  # An address nobody registered still costs a hash comparison. Skipping it would answer
  # faster than a wrong password does, and the difference is enough to learn which
  # addresses have accounts without ever guessing one right.
  defp verified?(nil, _password) do
    Bcrypt.no_user_verify()

    false
  end

  defp verified?(user, password) do
    Bcrypt.verify_pass(password, user.password_hash)
  end
end
