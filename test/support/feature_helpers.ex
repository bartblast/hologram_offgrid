defmodule Offgrid.FeatureHelpers do
  @moduledoc """
  Helpers the feature tests share, imported by `Offgrid.FeatureCase`: fixtures, signing in,
  pointer and date input, and two assertions that replace Wallaby's.
  """

  import Hologram.Test.FeatureHelpers, only: [assert_page: 2, visit: 3]
  import Wallaby.Query, only: [button: 1, css: 1, css: 2]

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
  alias Offgrid.Pages.SignUpPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage
  alias Wallaby.Browser
  alias Wallaby.Element
  alias Wallaby.Query
  alias Wallaby.Query.ErrorMessage
  alias Wallaby.StaleReferenceError

  @max_wait_time Application.compile_env(:wallaby, :max_wait_time, 3_000)

  @typedoc """
  One pointer event for `dispatch_pointer/3`: its kind, the element it is dispatched on, and
  where it happens - an offset from the map's top left, or `:target` for just inside the
  target's own top left.
  """
  @type pointer_event ::
          {:down | :move | :up, pointer_target, {number, number} | :target}

  @typedoc """
  What a pointer event is dispatched on: the first element a CSS selector matches, the first
  one it matches whose text includes the given string, or the document.
  """
  @type pointer_target :: String.t() | {String.t(), String.t()} | :document

  @doc """
  Asserts that the element `query` finds inside `parent` contains `text`, and returns
  `parent` so it can sit in a pipe - Wallaby's version returns the element it found.
  """
  @spec assert_text(struct, Query.t(), String.t()) :: struct
  def assert_text(parent, query, text) do
    Browser.assert_text(parent, query, text)

    parent
  end

  @doc """
  Creates a basemap with the given name and slug and returns it.

  The bounds are always Japan's, so a stop in Kyoto lands on the map and one in Warsaw is off
  its edge, whatever the basemap is called.
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
  Creates a remark by the given author on the given stop and returns it.
  """
  @spec create_comment(struct, struct, String.t()) :: struct
  def create_comment(author, stop, body) do
    %{author_id: author.id, body: body, stop_id: stop.id}
    |> Comment.new()
    |> DB.create!()
  end

  @doc """
  Creates a line by the given author on the given trip and returns it.

  The colour and the points can be given. By default the line is red and short, stored the way
  one is: an SVG path in the map's own coordinates, longitude across and latitude negated.
  """
  @spec create_sketch(struct, struct, keyword | map) :: struct
  def create_sketch(author, trip, attrs \\ []) do
    %{color: "#ff2d55", points: "M135.7,-35.1 L135.9,-35.2"}
    |> Map.merge(Map.new(attrs))
    |> Map.merge(%{author_id: author.id, trip_id: trip.id})
    |> Sketch.new()
    |> DB.create!()
  end

  @doc """
  Creates a stop on the given trip and returns it. The attributes usually name it and give its
  day; the rest are optional.
  """
  @spec create_stop(struct, keyword | map) :: struct
  def create_stop(trip, attrs) do
    attrs
    |> Map.new()
    |> Map.put(:trip_id, trip.id)
    |> Stop.new()
    |> DB.create!()
  end

  @doc """
  Creates a trip on a new Japan basemap and returns the trip.
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
  Creates a user with a real password hash and returns it. The password defaults to
  `password/0`, so any user created here can log in.
  """
  @spec create_user(String.t(), String.t(), String.t()) :: struct
  def create_user(name, email, password \\ password()) do
    %{email: email, name: name, password_hash: Bcrypt.hash_pwd_salt(password)}
    |> User.new()
    |> DB.create!()
  end

  @doc """
  Dispatches the given pointer events in order and returns the session. Offsets are measured
  from the map's top left, which is where the ink layer starts too.

  Dispatched by script, because a driver cannot hold a real drag half-way. With `delay:` (in
  milliseconds) the events are spaced that far apart and the call returns before they finish.
  """
  @spec dispatch_pointer(struct, [pointer_event], keyword) :: struct
  def dispatch_pointer(session, events, opts \\ []) do
    run =
      case Keyword.get(opts, :delay) do
        nil ->
          "events.forEach(fire);"

        delay ->
          "events.forEach((event, index) => setTimeout(() => fire(event), index * #{delay}));"
      end

    Browser.execute_script(session, """
    const box = document.getElementById('canvas').getBoundingClientRect();
    const events = #{JSON.encode!(Enum.map(events, &encode_pointer_event/1))};

    const fire = ({type, selector, text, origin, x, y}) => {
      const target = selector === null
        ? document
        : Array.from(document.querySelectorAll(selector)).find(element => text === null || element.textContent.includes(text));
      const from = origin === 'target' ? target.getBoundingClientRect() : box;

      target.dispatchEvent(new PointerEvent(type, {bubbles: true, clientX: from.left + x, clientY: from.top + y}));
    };

    #{run}
    """)

    session
  end

  @doc """
  A whole stroke over the ink layer: pressed at the first offset, moved through the rest,
  released at the last.
  """
  @spec drag(struct, [{number, number}]) :: struct
  def drag(session, points) do
    session
    |> press(points)
    |> release(List.last(points))
  end

  @doc """
  Sets the date input with the given id to `value` (an ISO date) and returns the session.

  Set by script because `fill_in` and `Element.set_value/2` send keystrokes, which land in the
  wrong segments of a `type="date"` control. Assigning the value and dispatching `input` is
  what the browser's own picker does.
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
  Logs in through the log-in card with the given email and password, asserts it reached the
  trips list, and returns the session.
  """
  @spec log_in(struct, String.t(), String.t()) :: struct
  def log_in(session, email, password \\ password()) do
    session
    |> visit(LogInPage, [])
    |> Browser.fill_in(css("#log_in_email"), with: email)
    |> Browser.fill_in(css("#log_in_password"), with: password)
    |> Browser.click(button("Log in"))
    |> assert_page(TripsPage)
  end

  @doc """
  The one password the suite's users have.
  """
  @spec password() :: String.t()
  def password, do: "hakone-2026"

  @doc """
  Presses the pointer on the ink layer at the first offset and moves it through the rest,
  leaving it down so a test can inspect a stroke mid-draw.
  """
  @spec press(struct, [{number, number}]) :: struct
  def press(session, [first | rest]) do
    dispatch_pointer(session, [{:down, ".ink", first} | Enum.map(rest, &{:move, ".ink", &1})])
  end

  @doc """
  Refutes that `query` matches inside `parent`, and returns `parent`.

  Returns as soon as the element is absent, where Wallaby's version always waits out
  `:max_wait_time`. An element still present is waited on until it goes or the time runs out.
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

  @doc """
  Lifts the pointer from the ink layer at the given offset, which is what turns a stroke
  into a row.
  """
  @spec release(struct, {number, number}) :: struct
  def release(session, at) do
    dispatch_pointer(session, [{:up, ".ink", at}])
  end

  @doc """
  Empties every table the app writes, in one statement - PostgreSQL refuses to truncate a
  referenced table unless the tables referencing it go in the same statement.
  """
  @spec reset_data() :: :ok
  def reset_data do
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
  Returns every point of the route on the map, in route order, as `{x, y}` in hundredths of
  the map.

  Found with `visible: :any` because a browser calls a line through a single point invisible.
  """
  @spec route_points(struct) :: [{float, float}]
  def route_points(session) do
    session
    |> Browser.find(css(".lay polyline", visible: :any))
    |> Element.attr("points")
    |> String.split(" ", trim: true)
    |> Enum.map(fn pair ->
      [x, y] = String.split(pair, ",")

      {String.to_float(x), String.to_float(y)}
    end)
  end

  @doc """
  Signs the browser in as a new user and returns the session on the given trip's screen.

  `role:` is the role granted on the trip: `:member` (the default), `:organizer`, or nil for
  somebody with no role on it. The name and email default per role, and a nil role needs both.
  The role is granted directly, and signing in goes through the log-in card, because only the
  server can mint a session cookie.
  """
  @spec sign_in(struct, struct, keyword) :: struct
  def sign_in(session, trip, opts \\ []) do
    role = Keyword.get(opts, :role, :member)
    {name, email} = identity(role, opts)

    user = create_user(name, email)
    :ok = grant(user, trip, role)

    session
    |> log_in(user.email)
    |> visit(TripPage, id: trip.id)
  end

  @doc """
  Fills in the sign-up card and submits it, and returns the session. It does not assert where
  that lands, so a feature can check a refusal too.
  """
  @spec sign_up(struct, String.t(), String.t(), String.t()) :: struct
  def sign_up(session, name, email, password \\ password()) do
    session
    |> visit(SignUpPage, [])
    |> Browser.fill_in(css("#sign_up_name"), with: name)
    |> Browser.fill_in(css("#sign_up_email"), with: email)
    |> Browser.fill_in(css("#sign_up_password"), with: password)
    |> Browser.click(button("Create account"))
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

  # Six pixels in from the target's own top left lands on it whatever its size.
  defp encode_pointer_event({kind, target, at}) do
    {selector, text} = pointer_selector(target)

    {origin, x, y} =
      case at do
        :target -> {"target", 6, 6}
        {x, y} -> {"canvas", x, y}
      end

    %{origin: origin, selector: selector, text: text, type: "pointer#{kind}", x: x, y: y}
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

  defp grant(_user, _trip, nil), do: :ok

  defp grant(user, trip, role), do: Auth.grant_role(user, trip, role)

  defp identity(nil, opts), do: {Keyword.fetch!(opts, :name), Keyword.fetch!(opts, :email)}

  defp identity(:member, opts) do
    {Keyword.get(opts, :name, "Nora Vale"), Keyword.get(opts, :email, "member@offgrid.test")}
  end

  defp identity(:organizer, opts) do
    {Keyword.get(opts, :name, "Iris Kalm"), Keyword.get(opts, :email, "organizer@offgrid.test")}
  end

  defp pointer_selector(:document), do: {nil, nil}

  defp pointer_selector({selector, text}), do: {selector, text}

  defp pointer_selector(selector), do: {selector, nil}

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
