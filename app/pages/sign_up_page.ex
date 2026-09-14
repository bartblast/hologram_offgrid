defmodule Offgrid.Pages.SignUpPage do
  @moduledoc """
  The card a person makes an account on. The fields live in page state, and the button hands
  them to a command, because a browser cannot be trusted to say who it is: the password is
  hashed, the row written and the session set on the server.

  `User` grants nobody `:create`, so the command claims server authority with `trust/1`. A
  client's batch carries field values and never a claim, so no browser can create an account.
  """

  use Hologram.Page
  use Hologram.DB

  alias Hologram.UI.Link
  alias Offgrid.Components.Terrain
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripsPage

  route "/sign-up"

  layout Offgrid.Components.DefaultLayout

  middleware Offgrid.Middleware.GuestOnly

  @password_min_length 8

  def init(_params, component, _server) do
    put_state(component, email: "", error: nil, name: "", password: "")
  end

  def template do
    ~HOLO"""
    <div class="app">
      <div class="map">
        <Terrain />

        <div class="card">
          <h2>Create your account</h2>
          <p class="sub">Offgrid works wherever you do.</p>

          <label>Name</label>
          <input class="inp" value={@name} $change={:edit, field: :name} $key_down.enter="sign_up" />

          <label>Email</label>
          <input
            class="inp"
            type="email"
            value={@email}
            $change={:edit, field: :email}
            $key_down.enter="sign_up"
          />

          {%if @error}
            <p class="err">{@error}</p>
          {/if}

          <label>Password</label>
          <input
            class="inp"
            type="password"
            value={@password}
            $change={:edit, field: :password}
            $key_down.enter="sign_up"
          />

          <button class="btn" type="button" $click="sign_up">Create account</button>

          <p class="alt">Have an account? <Link to={LogInPage}>Log in</Link></p>
        </div>
      </div>
    </div>
    """
  end

  def action(:edit, params, component) do
    put_state(component, params.field, params.event.value)
  end

  # Clearing the error first, so a retry does not show the old refusal until the server answers.
  def action(:sign_up, _params, component) do
    component
    |> put_state(:error, nil)
    |> put_command(:sign_up,
      email: component.state.email,
      name: component.state.name,
      password: component.state.password
    )
  end

  def action(:sign_up_failed, params, component) do
    put_state(component, :error, params.message)
  end

  # A new account is on no trips, and the empty trips list offers the way to start one.
  def action(:signed_up, _params, component) do
    put_page(component, TripsPage)
  end

  # The length is checked here rather than on the entity, which stores only the hash, and before
  # hashing, which is slow.
  def command(:sign_up, params, server) do
    if String.length(params.password) < @password_min_length do
      put_action(server, :sign_up_failed, %{message: password_message()})
    else
      register(params, server)
    end
  end

  defp register(params, server) do
    password_hash = Bcrypt.hash_pwd_salt(params.password)

    result =
      %{email: params.email, name: params.name, password_hash: password_hash}
      |> User.new()
      |> trust()
      |> DB.create()

    case result do
      {:ok, user} ->
        server
        |> put_user_id(user.id)
        |> put_action(:signed_up)

      {:error, violations} ->
        put_action(server, :sign_up_failed, %{message: message(violations)})
    end
  end

  # One sentence naming the field to fix, in the order the card asks for them. The map may hold
  # several keys, so the first matching clause wins.
  defp message(%{name: _violations}), do: "Tell us your name."

  defp message(%{email: [:unique]}), do: "That email is already taken."

  defp message(%{email: _violations}), do: "Enter your email."

  defp message(_violations), do: "Check the form and try again."

  defp password_message do
    "Choose a password of at least #{@password_min_length} characters."
  end
end
