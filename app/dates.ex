defmodule Offgrid.Dates do
  @moduledoc """
  How a trip's dates are spelled on screen.

  One function for two places that show the same span - the row in the trips list and the
  header of the itinerary panel - which differ only in the casing their stylesheet gives them.
  """

  @doc """
  Returns the date a `type="date"` input spells as `value`, or nil when it spells nothing yet
  or something that is not a date at all.

  Written out rather than handed to `Date.from_iso8601/1`, which the client does not have.
  Nothing here raises: a part that is not a whole number, or a day that does not exist, is
  nil the same as an empty field, so a caller has one thing to check.
  """
  @spec parse(String.t()) :: Date.t() | nil
  def parse(value) do
    with [year, month, day] <- String.split(value, "-"),
         {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {day, ""} <- Integer.parse(day),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _other -> nil
    end
  end

  @doc """
  Returns the date spelled the way a `type="date"` input wants its `value`, and the empty
  string for no date at all.
  """
  @spec to_input(Date.t() | nil) :: String.t()
  def to_input(nil), do: ""

  def to_input(date) do
    month = if date.month < 10, do: "0#{date.month}", else: "#{date.month}"
    day = if date.day < 10, do: "0#{date.day}", else: "#{date.day}"

    "#{date.year}-#{month}-#{day}"
  end

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
