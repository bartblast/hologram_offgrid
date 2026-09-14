defmodule Offgrid.Classes do
  @moduledoc """
  Builds a `class` attribute out of names that are always on and names that depend on a
  condition: `classes(["pen", on: drawing, flush: !panel_open])` is `"pen on flush"` while
  both conditions hold.
  """

  @doc """
  Returns the class names from the given list, space-separated. A string is always included,
  and a `name: condition` entry only when its condition is truthy.
  """
  @spec classes(list(String.t() | {atom, term})) :: String.t()
  def classes(entries) do
    entries
    |> Enum.flat_map(&names/1)
    |> Enum.join(" ")
  end

  defp names({name, condition}), do: if(condition, do: [Atom.to_string(name)], else: [])

  defp names(name), do: [name]
end
