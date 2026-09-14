defmodule Offgrid.Utils.CSS do
  @moduledoc """
  Builds a `class` attribute out of names that are always on and names that depend on a
  condition: `CSS.class(["pen", on: drawing, flush: !panel_open])` is `"pen on flush"` while
  both conditions hold.
  """

  @doc """
  Returns the class names from the given list, space-separated. A string is always included,
  and a `name: condition` entry only when its condition is truthy.
  """
  @spec class(list(String.t() | {atom, term})) :: String.t()
  def class(entries) do
    entries
    |> Enum.flat_map(&names/1)
    |> Enum.join(" ")
  end

  defp names({_name, condition}) when condition in [nil, false], do: []

  defp names({name, _condition}), do: [Atom.to_string(name)]

  defp names(name), do: [name]
end
