defmodule Offgrid.Dates do
  @moduledoc """
  How a trip's dates are spelled on screen.

  One function for two places that show the same span - the row in the trips list and the
  header of the itinerary panel - which differ only in the casing their stylesheet gives them.
  """

  @doc """
  Returns the span between the two dates as one line: "28 Mar – 6 Apr", or "28 – 30 Mar" when
  a single month covers it.

  The month is repeated only when it changes, because repeating it is noise the reader has to
  look past to find the days, which are what they came for.
  """
  @spec span(Date.t(), Date.t()) :: String.t()
  def span(starts_on, ends_on) do
    if starts_on.month == ends_on.month do
      "#{starts_on.day} – #{ends_on.day} #{month(ends_on.month)}"
    else
      "#{starts_on.day} #{month(starts_on.month)} – #{ends_on.day} #{month(ends_on.month)}"
    end
  end

  defp month(1), do: "Jan"

  defp month(2), do: "Feb"

  defp month(3), do: "Mar"

  defp month(4), do: "Apr"

  defp month(5), do: "May"

  defp month(6), do: "Jun"

  defp month(7), do: "Jul"

  defp month(8), do: "Aug"

  defp month(9), do: "Sep"

  defp month(10), do: "Oct"

  defp month(11), do: "Nov"

  defp month(12), do: "Dec"
end
