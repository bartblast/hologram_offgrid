# Seeds the maps the app offers and the trip the demo opens on. Idempotent - a row already
# there is left alone, so running this twice is safe.
#
#     HOLOGRAM_START=1 mix run priv/seeds.exs
#
# HOLOGRAM_START=1 matters: in dev and test the data layer does not start without it,
# and DB.create has nothing to write to.

import Hologram.Query, only: [filter: 2, one: 1]

alias Hologram.DB
alias Offgrid.Entities.Basemap
alias Offgrid.Entities.Stop
alias Offgrid.Entities.Trip

# The three maps a trip can be drawn on, at three deliberately different scales - a country,
# a city and a mountain range - so the projection is exercised by more than one size of box.
# Real bounds: they decide where a stop's coordinates land on screen, so inventing them would
# put the pins in the wrong places.
basemaps = [
  %{
    max_lat: 45.6,
    max_lng: 146.0,
    min_lat: 30.9,
    min_lng: 128.4,
    name: "Japan",
    slug: "japan"
  },
  %{
    max_lat: 52.37,
    max_lng: 21.27,
    min_lat: 52.09,
    min_lng: 20.85,
    name: "Warsaw",
    slug: "warsaw"
  },
  %{
    max_lat: 48.0,
    max_lng: 16.2,
    min_lat: 43.6,
    min_lng: 5.0,
    name: "The Alps",
    slug: "alps"
  }
]

Enum.each(basemaps, fn attrs ->
  existing =
    Basemap
    |> filter(slug: attrs.slug)
    |> one()
    |> DB.read()

  if existing do
    IO.puts("· #{attrs.name}")
  else
    {:ok, _basemap} =
      attrs
      |> Basemap.new()
      |> DB.create()

    IO.puts("+ #{attrs.name}")
  end
end)

# Real coordinates - the map they are drawn on is stylised, the places are not.
# The trip the demo opens on, drawn on Japan. Seeds run as trusted code - no session, no
# acting user - so this is written past the policies the way a migration would be, and it
# gets no organizer: granted_to: :creator grants to an ACTING user, and there is none here.
# The seeded trip therefore has no members, which is correct and is what E4 onwards fixes by
# making trips through the interface instead.
japan =
  Basemap
  |> filter(slug: "japan")
  |> one()
  |> DB.read()

trip_name = "Japan, blossom run"

trip =
  case Trip |> filter(name: trip_name) |> one() |> DB.read() do
    nil ->
      {:ok, created} =
        %{
          basemap_id: japan.id,
          ends_on: ~D[2026-04-06],
          name: trip_name,
          starts_on: ~D[2026-03-28]
        }
        |> Trip.new()
        |> DB.create()

      IO.puts("+ #{trip_name}")

      created

    existing ->
      IO.puts("· #{trip_name}")

      existing
  end

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
      |> Map.put(:trip_id, trip.id)
      |> Stop.new()
      |> DB.create()

    IO.puts("+ #{attrs.name}")
  end
end)

# Whatever else is in the database gets the trip too - a stop written through the interface
# before the column existed has none, and the next commit makes the reference required, which
# no row may be missing by then. This is the backfill step, and it is a sweep rather than a
# list because the rows it has to reach were never named here.
orphans =
  Stop
  |> filter(trip_id: nil)
  |> DB.read()

Enum.each(orphans, fn stop ->
  :ok = DB.update(Stop, stop.id, %{trip_id: trip.id})

  IO.puts("~ #{stop.name} joined #{trip_name}")
end)
