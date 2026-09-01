defmodule Offgrid.FeatureHelpers do
  alias Wallaby.Browser

  @moduledoc """
  Assertions the feature tests use in place of Wallaby's, imported by `Offgrid.FeatureCase`.
  """

  @doc """
  Asserts that the element `query` finds inside `parent` contains `text`, and returns
  `parent` so the assertion can sit in the middle of a pipe.

  Wallaby's own three-argument version returns the element it found rather than what it was
  given, which ends a pipe of session steps.
  """
  @spec assert_text(struct, Wallaby.Query.t(), String.t()) :: struct
  def assert_text(parent, query, text) do
    Browser.assert_text(parent, query, text)

    parent
  end
end
