defmodule Offgrid.FeatureHelpers do
  alias Hologram.DB
  alias Hologram.DB.Connection
  alias Hologram.DB.Mapper
  alias Offgrid.Entities.Basemap
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
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
  Creates a trip with a basemap under it and returns the trip - the two rows that have to
  exist before any stop can, since a stop's trip is required and a trip's basemap is.
  """
  @spec create_trip() :: struct
  def create_trip do
    basemap =
      %{
        max_lat: 45.6,
        max_lng: 146.0,
        min_lat: 30.9,
        min_lng: 128.4,
        name: "Japan",
        slug: "japan"
      }
      |> Basemap.new()
      |> DB.create!()

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
  Empties every table a trip's data lives in, in one statement.

  One statement because PostgreSQL refuses to truncate a table something references unless
  the referencing one goes with it, and the three form a chain: a stop names its trip, a
  trip names its basemap.
  """
  @spec truncate_trip_data() :: :ok
  def truncate_trip_data do
    tables =
      Enum.map_join([Stop, Trip, Basemap], ", ", fn entity_type ->
        ~s("hologram_data"."#{Mapper.table_name(entity_type)}")
      end)

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
