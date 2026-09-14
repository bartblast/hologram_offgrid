defmodule Offgrid.Utils.DateFormat do
  @moduledoc """
  How dates and times are spelled on screen, and how a date input's spelling is read back.

  One place for every spelling, so the screens that show dates cannot drift apart. Each
  function takes a date or a time rather than an entity.
  """

  @doc """
  Returns the time of day of the given UTC timestamp as a clock reading in the browser's zone,
  given the minutes the browser is behind UTC: "14:05".

  Integer arithmetic wrapped at midnight rather than a `DateTime` shift, so it needs nothing
  beyond what the client runtime has.
  """
  @spec clock(DateTime.t() | NaiveDateTime.t(), integer) :: String.t()
  def clock(at, offset_minutes) do
    minutes = Integer.mod(at.hour * 60 + at.minute - offset_minutes, 1_440)

    "#{pad(div(minutes, 60))}:#{pad(rem(minutes, 60))}"
  end

  @doc """
  Returns the date as the itinerary and the editor label a day: "Sat 28 Mar".
  """
  @spec day_label(Date.t()) :: String.t()
  def day_label(date) do
    "#{weekday(date)} #{date.day} #{month(date.month)}"
  end

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
  Returns the date spelled the way a `type="date"` input wants its `value`, and the empty
  string for no date at all.
  """
  @spec to_input(Date.t() | nil) :: String.t()
  def to_input(nil), do: ""

  def to_input(date), do: "#{date.year}-#{pad(date.month)}-#{pad(date.day)}"

  @doc """
  Returns the date's weekday as its three-letter name.
  """
  @spec weekday(Date.t()) :: String.t()
  def weekday(date), do: weekday_name(Date.day_of_week(date))

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

  # A leading zero below ten, which is what every clock reading here wants of its hours and
  # minutes.
  defp pad(number) when number < 10, do: "0#{number}"

  defp pad(number), do: "#{number}"

  defp weekday_name(1), do: "Mon"
  defp weekday_name(2), do: "Tue"
  defp weekday_name(3), do: "Wed"
  defp weekday_name(4), do: "Thu"
  defp weekday_name(5), do: "Fri"
  defp weekday_name(6), do: "Sat"
  defp weekday_name(7), do: "Sun"
end
