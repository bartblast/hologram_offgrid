# Seeds the trip the demo opens on. Idempotent - a stop already there is left alone,
# so running this twice is safe.
#
#     HOLOGRAM_START=1 mix run priv/seeds.exs
#
# HOLOGRAM_START=1 matters: in dev and test the data layer does not start without it,
# and DB.create has nothing to write to.

import Hologram.Query, only: [filter: 2, one: 1]

alias Hologram.DB
alias Offgrid.Entities.Stop

# Real coordinates - the map they are drawn on is stylised, the places are not.
stops = [
  %{
    date: ~D[2026-03-28],
    description: "Arrival, then straight to the hotel",
    lat: 35.5494,
    lng: 139.7798,
    name: "Haneda → Shinjuku",
    time: ~T[14:20:00]
  },
  %{
    date: ~D[2026-03-28],
    description: "Best pour-over in town",
    lat: 35.6684,
    lng: 139.6833,
    name: "Coffee at Fuglen"
  },
  %{
    date: ~D[2026-03-30],
    description: "Two nights, onsen on site",
    lat: 35.2324,
    lng: 139.1069,
    name: "Ryokan",
    time: ~T[11:00:00]
  },
  %{
    date: ~D[2026-04-01],
    description: "Before 7am or forget it",
    lat: 34.9671,
    lng: 135.7727,
    name: "Fushimi Inari",
    time: ~T[06:30:00]
  }
]

Enum.each(stops, fn attrs ->
  existing =
    Stop
    |> filter(name: attrs.name)
    |> one()
    |> DB.read()

  if existing do
    IO.puts("· #{attrs.name}")
  else
    {:ok, _stop} =
      attrs
      |> Stop.new()
      |> DB.create()

    IO.puts("+ #{attrs.name}")
  end
end)
