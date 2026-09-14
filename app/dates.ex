defmodule Offgrid.Dates do
  @moduledoc """
  How dates and times are spelled on screen.

  One place for every spelling, so the screens that show dates cannot drift apart. Each
  function takes a date or a time rather than an entity.
  """

  @doc """
  Returns the date as the itinerary and the editor label a day: "Sat 28 Mar".
  """
  @spec day_label(Date.t()) :: String.t()
  def day_label(date) do
    "#{weekday(date)} #{date.day} #{month(date.month)}"
  end

  @doc """
  Returns the month's three-letter name, by its number.
  """
  @spec month(1..12) :: String.t()
  def month(1), do: "Jan"
  def month(2), do: "Feb"
  def month(3), do: "Mar"
  def month(4), do: "Apr"
  def month(5), do: "May"
  def month(6), do: "Jun"
  def month(7), do: "Jul"
  def month(8), do: "Aug"
  def month(9), do: "Sep"
  def month(10), do: "Oct"
  def month(11), do: "Nov"
  def month(12), do: "Dec"

  @doc """
  Returns the number with a leading zero below ten, which is what every clock reading here
  wants of its hours and minutes.
  """
  @spec pad(non_neg_integer) :: String.t()
  def pad(number) when number < 10, do: "0#{number}"

  def pad(number), do: "#{number}"

  @doc """
  Returns the date a `type="date"` input spells as `value`, or nil when it spells nothing yet
  or something that is not a date at all.

  Parsed by hand so it also runs on the client. Nothing here raises: a part that is not a whole
  number, or a day that does not exist, is nil the same as an empty field.
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

  def to_input(date), do: "#{date.year}-#{pad(date.month)}-#{pad(date.day)}"

  @doc """
  Returns the span between the two dates as one line: "28 Mar – 6 Apr", or "28 – 30 Mar" when
  a single month covers it.
  """
  @spec span(Date.t(), Date.t()) :: String.t()
  def span(starts_on, ends_on) do
    if starts_on.month == ends_on.month do
      "#{starts_on.day} – #{ends_on.day} #{month(ends_on.month)}"
    else
      "#{starts_on.day} #{month(starts_on.month)} – #{ends_on.day} #{month(ends_on.month)}"
    end
  end

  @doc """
  Returns the time of day as a clock reading: "09:05".
  """
  @spec time_label(Time.t()) :: String.t()
  def time_label(time), do: "#{pad(time.hour)}:#{pad(time.minute)}"

  @doc """
  Returns the date's weekday as its three-letter name.
  """
  @spec weekday(Date.t()) :: String.t()
  def weekday(date), do: weekday_name(Date.day_of_week(date))

  defp weekday_name(1), do: "Mon"
  defp weekday_name(2), do: "Tue"
  defp weekday_name(3), do: "Wed"
  defp weekday_name(4), do: "Thu"
  defp weekday_name(5), do: "Fri"
  defp weekday_name(6), do: "Sat"
  defp weekday_name(7), do: "Sun"
end
