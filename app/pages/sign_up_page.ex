defmodule Offgrid.Pages.SignUpPage do
  use Hologram.Page
  use Hologram.DB

  alias Offgrid.Components.Terrain
  alias Offgrid.Entities.User
  alias Offgrid.Pages.TripPage

  @moduledoc """
  The card a person makes an account on, over the same map every other screen shows.

  The three fields write to page state as they are typed, and the button hands them to a
  command. Everything about an account happens on the server: the password is hashed
  there, the row is written there, and the session identity is set there. Nothing about
  signing up is local-first, and that is the correct answer rather than a gap - a browser
  cannot be trusted to say who it is.

  The write is trusted because nobody is signed in yet. A command runs under whatever actor
  the session carries, so the same call made by an already signed-in visitor is judged
  against the policy instead, where nothing grants :create, and refused.

  What comes back is an action either way. On success the server has already put the user
  id on the session, so the page just navigates. On failure the message renders under the
  email field, which is where the one failure worth naming belongs.
  """

  route "/sign-up"

  layout Offgrid.DefaultLayout

  def init(_params, component, _server) do
    component
    |> put_state(:email, "")
    |> put_state(:error, nil)
    |> put_state(:name, "")
    |> put_state(:password, "")
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
          <input class="inp" value={@name} $change={:edit, field: :name} />

          <label>Email</label>
          <input class="inp" type="email" value={@email} $change={:edit, field: :email} />

          {%if @error}
            <p class="err">{@error}</p>
          {/if}

          <label>Password</label>
          <input class="inp" type="password" value={@password} $change={:edit, field: :password} />

          <button class="btn" type="button" $click="sign_up">Create account</button>

          <!-- TODO: point this at the log-in page once that page exists. -->
          <p class="alt">Have an account? <a href="#">Log in</a></p>
        </div>
      </div>
    </div>
    """
  end

  def action(:edit, params, component) do
    put_state(component, params.field, params.event.value)
  end

  # The page holds what was typed, so the command is handed values rather than reading a
  # form. Clearing the error here means a second attempt starts clean instead of showing
  # the previous refusal until the round trip answers.
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

  def action(:signed_up, _params, component) do
    put_page(component, TripPage)
  end

  def command(:sign_up, params, server) do
    password_hash = Bcrypt.hash_pwd_salt(params.password)

    result =
      %{email: params.email, name: params.name, password_hash: password_hash}
      |> User.new()
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

  # The taken email is the only refusal worth naming: it is the one a person can act on,
  # and it is the one that happens. Everything else the entity refuses is a field they can
  # see is empty.
  defp message(%{email: [:unique]}), do: "That email is already taken."

  defp message(_violations), do: "Check the form and try again."
end
