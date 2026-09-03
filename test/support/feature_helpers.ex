defmodule Offgrid.FeatureHelpers do
  import Hologram.Test.FeatureHelpers, only: [assert_page: 2, visit: 3]
  import Wallaby.Query, only: [button: 1, css: 2]

  alias Hologram.Auth
  alias Hologram.Auth.RoleGrant
  alias Hologram.DB
  alias Hologram.DB.Connection
  alias Hologram.DB.Mapper
  alias Offgrid.Entities.Basemap
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage
  alias Wallaby.Browser
  alias Wallaby.Element
  alias Wallaby.Query
  alias Wallaby.Query.ErrorMessage
  alias Wallaby.StaleReferenceError

  @moduledoc """
  What every feature test needs and Wallaby does not give it, imported by
  `Offgrid.FeatureCase`: the two assertions that replace Wallaby's, and the fixtures for
  data the entity declarations make mandatory.
  """

  @max_wait_time Application.compile_env(:wallaby, :max_wait_time, 3_000)

  @doc """
  Creates a basemap with the given name and slug and returns it.

  The bounds are Japan's whatever the map is called. Nothing reads them yet - the projection
  arrives with the pins - and a test that needs honest ones will say so by needing them.
  """
  @spec create_basemap(String.t(), String.t()) :: struct
  def create_basemap(name, slug) do
    %{
      max_lat: 45.6,
      max_lng: 146.0,
      min_lat: 30.9,
      min_lng: 128.4,
      name: name,
      slug: slug
    }
    |> Basemap.new()
    |> DB.create!()
  end

  @doc """
  Creates a trip with a basemap under it and returns the trip - the two rows that have to
  exist before any stop can, since a stop's trip is required and a trip's basemap is.
  """
  @spec create_trip() :: struct
  def create_trip do
    basemap = create_basemap("Japan", "japan")

    %{
      basemap_id: basemap.id,
      ends_on: ~D[2026-04-06],
      name: "Japan, blossom run",
      starts_on: ~D[2026-03-28]
    }
    |> Trip.new()
    |> DB.create!()
  end

  @doc """
  Signs the browser in as a member of the given trip and returns the session, landing on the
  trip screen.

  A stop is visible only to a member of its trip, so a test that wants to see one needs both
  halves: a user with a grant on that trip, and a browser carrying that user's session. The
  grant is written directly - the interface for adding members does not exist yet - and the
  signing in goes through the log-in card, because a session cookie is the server's to mint
  and there is no other door to it.
  """
  @spec sign_in_as_member(struct, struct) :: struct
  def sign_in_as_member(session, trip) do
    sign_in(session, trip, :member, "Nora Vale")
  end

  @doc """
  Signs the browser in as an organizer of the given trip and returns the session, landing on
  the trip screen.

  The same two halves as `sign_in_as_member/2`, with the role that may change who else is on
  the trip - which is what the controls for adding and removing people are gated on.
  """
  @spec sign_in_as_organizer(struct, struct) :: struct
  def sign_in_as_organizer(session, trip) do
    sign_in(session, trip, :organizer, "Iris Kalm")
  end

  @doc """
  Sets the date input with the given id to `value` (an ISO date) and returns the session.

  Neither `fill_in` nor `Element.set_value/2` works here, and both fail the same way: a
  `type="date"` control is segmented, and both send keystrokes, so the characters go to
  whichever segment has focus. "2026-05-15" typed into one lands as year 60515, month 02,
  day 20 - a real Date, five digits wide, which then fails the wire format. Assigning the
  value and dispatching `input` is what the browser's own picker does, and the only way to
  put a whole date in from a test.
  """
  @spec fill_date(struct, String.t(), String.t()) :: struct
  def fill_date(session, id, value) do
    Browser.execute_script(session, """
    const input = document.getElementById("#{id}");
    input.value = "#{value}";
    input.dispatchEvent(new Event("input", {bubbles: true}));
    """)

    session
  end

  @doc """
  Empties every table a trip's data lives in, in one statement.

  One statement because PostgreSQL refuses to truncate a table something references unless
  the referencing one goes with it, and these form a chain: a comment names its stop and its
  author, a sketch names its trip and its author, a stop names its trip, a trip names its
  basemap, and a grant names both a user and the entity it is held on.
  """
  @spec truncate_trip_data() :: :ok
  def truncate_trip_data do
    tables =
      Enum.map_join(
        [Comment, Sketch, Stop, Trip, RoleGrant, User, Basemap],
        ", ",
        fn entity_type ->
          ~s("hologram_data"."#{Mapper.table_name(entity_type)}")
        end
      )

    {:ok, _result} = Connection.query("TRUNCATE #{tables}", [])

    :ok
  end

  @doc """
  Asserts that the element `query` finds inside `parent` contains `text`, and returns
  `parent` so the assertion can sit in the middle of a pipe.

  Wallaby's own three-argument version returns the element it found rather than what it was
  given, which ends a pipe of session steps.
  """
  @spec assert_text(struct, Query.t(), String.t()) :: struct
  def assert_text(parent, query, text) do
    Browser.assert_text(parent, query, text)

    parent
  end

  @doc """
  Refutes that `query` matches inside `parent`, and returns `parent`.

  Returns as soon as the element is absent. Wallaby's own version retries until
  `:max_wait_time` elapses whether or not it ever finds anything, so an assertion about
  something that is already gone - the usual case after a delete - costs the full wait, and
  two of them in one test exhaust ExUnit's default timeout on their own.

  An element that is still present is still waited on, so this keeps catching the thing it
  is for: something that should disappear and does not.
  """
  @spec refute_has(struct, Query.t()) :: struct
  def refute_has(parent, query) do
    case refute_query(parent, query) do
      {:error, :invalid_selector} ->
        raise Wallaby.QueryError, ErrorMessage.message(query, :invalid_selector)

      {:error, _not_found} ->
        parent

      {:ok, found_query} ->
        raise Wallaby.ExpectationNotMetError, ErrorMessage.message(found_query, :found)
    end
  end

  defp sign_in(session, trip, role, name) do
    password = "hakone-2026"

    user =
      %{
        email: "#{role}@offgrid.test",
        name: name,
        password_hash: Bcrypt.hash_pwd_salt(password)
      }
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(user, trip, role)

    session
    |> visit(LogInPage, [])
    |> Browser.fill_in(css(".card .inp", at: 0), with: user.email)
    |> Browser.fill_in(css(".card .inp", at: 1), with: password)
    |> Browser.click(button("Log in"))
    # Signing in lands on the trips list. The helper goes on to the trip screen, which is what
    # every caller of it is actually after.
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
  end

  defp apply_at(query, elements) do
    case {Query.at_number(query), length(elements)} do
      {:all, _count} -> {:ok, elements}
      {number, count} when number < count -> {:ok, [Enum.at(elements, number)]}
      {_number, _count} -> {:error, {:not_found, elements}}
    end
  end

  defp current_time do
    :erlang.monotonic_time(:milli_seconds)
  end

  defp filter_by_selected(query, elements) do
    case Query.selected?(query) do
      :any -> {:ok, elements}
      true -> {:ok, Enum.filter(elements, &Element.selected?/1)}
      false -> {:ok, Enum.reject(elements, &Element.selected?/1)}
    end
  end

  defp filter_by_text(query, elements) do
    text = Query.inner_text(query)

    if text do
      {:ok, Enum.filter(elements, &text_matches?(&1, text))}
    else
      {:ok, elements}
    end
  end

  defp filter_by_visibility(query, elements) do
    case Query.visible?(query) do
      :any -> {:ok, elements}
      true -> {:ok, Enum.filter(elements, &Element.visible?/1)}
      false -> {:ok, Enum.reject(elements, &Element.visible?/1)}
    end
  end

  defp query_once(%{driver: driver} = parent, query) do
    with {:ok, %Query{} = validated_query} <- Query.validate(query),
         compiled_query <- Query.compile(validated_query),
         {:ok, elements} <- driver.find_elements(parent, compiled_query),
         {:ok, elements} <- filter_by_visibility(validated_query, elements),
         {:ok, elements} <- filter_by_text(validated_query, elements),
         {:ok, elements} <- filter_by_selected(validated_query, elements),
         {:ok, elements} <- validate_count(validated_query, elements),
         {:ok, elements} <- apply_at(validated_query, elements) do
      {:ok, %Query{validated_query | result: elements}}
    end
  rescue
    StaleReferenceError -> {:error, :stale_reference}
  end

  defp refute_query(parent, query, start_time \\ nil) do
    start_time = start_time || current_time()

    case query_once(parent, query) do
      {:ok, _query} = found ->
        if timed_out?(start_time) do
          found
        else
          refute_query(parent, query, start_time)
        end

      {:error, :stale_reference} ->
        refute_query(parent, query, start_time)

      {:error, :invalid_selector} = error ->
        error

      {:error, _not_found} = error ->
        error
    end
  end

  defp text_matches?(%Element{driver: driver} = element, text) do
    case driver.text(element) do
      {:ok, element_text} -> element_text =~ ~r/#{Regex.escape(text)}/
      {:error, _reason} -> false
    end
  end

  defp timed_out?(start_time) do
    current_time() - start_time > @max_wait_time
  end

  defp validate_count(query, elements) do
    if Query.matches_count?(query, Enum.count(elements)) do
      {:ok, elements}
    else
      {:error, {:not_found, elements}}
    end
  end
end
