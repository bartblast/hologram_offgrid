# Seeds the maps the app offers, four accounts, and the trips they share. Idempotent - a row
# already there is left alone, so running this twice is safe.
#
#     HOLOGRAM_START=1 mix run priv/seeds.exs
#
# HOLOGRAM_START=1 matters: in dev and test the data layer does not start without it,
# and DB.create has nothing to write to.
#
# A trip's stops, ink and remarks are only written together with the trip itself. A trip that
# already exists is skipped whole, so a second run never adds a copy of anything inside it.

import Hologram.Query, only: [filter: 2, one: 1]

alias Hologram.Auth
alias Hologram.DB
alias Offgrid.Entities.Basemap
alias Offgrid.Entities.Comment
alias Offgrid.Entities.Sketch
alias Offgrid.Entities.Stop
alias Offgrid.Entities.Trip
alias Offgrid.Entities.User
alias Offgrid.Stroke

# Reads the row matching `match`, or creates one from `attrs`. Tells the caller which happened,
# because a trip only gets its contents when it is new.
find_or_create = fn entity_type, match, attrs, label ->
  existing =
    entity_type
    |> filter(match)
    |> one()
    |> DB.read()

  if existing do
    Mix.shell().info("· #{label}")

    {:existing, existing}
  else
    created =
      attrs
      |> entity_type.new()
      |> DB.create!()

    Mix.shell().info("+ #{label}")

    {:created, created}
  end
end

# The three maps a trip can be drawn on, at three deliberately different scales - a country,
# a city and a mountain range - so the projection is exercised by more than one size of box.
#
# Japan's box is not the whole country. The itinerary panel covers the left of the screen and
# the stop panel the right, so a pin is only seen in the band between them. The box is wide in
# longitude, which squeezes a run from Kyoto to Tokyo into that band, and narrow in latitude,
# which spreads the same stops from the top of the map to the bottom.
basemaps =
  Map.new(
    [
      %{
        max_lat: 37.085,
        max_lng: 145.71,
        min_lat: 34.645,
        min_lng: 129.68,
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
    ],
    fn attrs ->
      {_status, basemap} = find_or_create.(Basemap, [slug: attrs.slug], attrs, attrs.name)

      {attrs.slug, basemap}
    end
  )

# One password for all four, so any of them can be signed in as.
password = "japan-2026"

people =
  Map.new(
    [
      {:bart, "Bart Blast", "bart@offgrid.test"},
      {:emilia, "Emilia Burza", "emilia@offgrid.test"},
      {:indiana, "Indiana Jones", "indiana@offgrid.test"},
      {:lara, "Lara Croft", "lara@offgrid.test"}
    ],
    fn {key, name, email} ->
      attrs = %{email: email, name: name, password_hash: Bcrypt.hash_pwd_salt(password)}

      {_status, user} = find_or_create.(User, [email: email], attrs, email)

      {key, user}
    end
  )

# Two more trips on Bart's list, created BEFORE the Japan one so it sorts to the top - the list
# is newest first.
for attrs <- [
      %{
        basemap_id: basemaps["warsaw"].id,
        ends_on: ~D[2026-05-18],
        name: "Warsaw, long weekend",
        starts_on: ~D[2026-05-15]
      },
      %{
        basemap_id: basemaps["alps"].id,
        ends_on: ~D[2026-08-09],
        name: "Alps, hut to hut",
        starts_on: ~D[2026-08-02]
      }
    ] do
  case find_or_create.(Trip, [name: attrs.name], attrs, attrs.name) do
    {:created, trip} -> :ok = Auth.grant_role(people.bart, trip, :organizer)
    {:existing, _trip} -> :ok
  end
end

japan_attrs = %{
  basemap_id: basemaps["japan"].id,
  ends_on: ~D[2026-04-06],
  name: "Japan, blossom run",
  starts_on: ~D[2026-03-28]
}

case find_or_create.(Trip, [name: japan_attrs.name], japan_attrs, japan_attrs.name) do
  {:existing, _trip} ->
    :ok

  {:created, japan} ->
    # Granted in this order on purpose: the cast's colours go by join order.
    :ok = Auth.grant_role(people.bart, japan, :organizer)
    :ok = Auth.grant_role(people.emilia, japan, :member)
    :ok = Auth.grant_role(people.indiana, japan, :member)
    :ok = Auth.grant_role(people.lara, japan, :member)

    # Real coordinates - the map they are drawn on is stylised, the places are not.
    stops =
      Map.new(
        [
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
            description: "Two hours north, then the shrines",
            lat: 36.7580,
            lng: 139.5986,
            name: "Nikko, the cedar road"
          },
          %{
            date: ~D[2026-03-28],
            lat: 36.1408,
            lng: 137.2520,
            name: "Takayama, morning market"
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
            name: "Fushimi Inari, at dawn",
            time: ~T[06:30:00]
          },
          %{
            date: ~D[2026-04-01],
            description: "Best garden in the country",
            lat: 36.5613,
            lng: 136.6562,
            name: "Kanazawa, Kenrokuen",
            time: ~T[16:00:00]
          }
        ],
        fn attrs ->
          stop =
            attrs
            |> Map.put(:trip_id, japan.id)
            |> Stop.new()
            |> DB.create!()

          Mix.shell().info("+ #{stop.name}")

          {stop.name, stop}
        end
      )

    %{
      author_id: people.bart.id,
      body: "Torii gates start at the second shrine",
      stop_id: stops["Fushimi Inari, at dawn"].id
    }
    |> Comment.new()
    |> DB.create!()

    Mix.shell().info("+ Bart's remark on Fushimi Inari")

    # A sketch stores its whole line as one SVG path in the map's own coordinates, x being
    # longitude and y being NEGATIVE latitude, the way the page writes one when a pointer lifts.
    # Points below are {lat, lng} for readability and turned around on the way in.
    ink = fn author, color, points ->
      path =
        points
        |> Enum.map(fn {lat, lng} -> {Float.round(lng, 4), Float.round(-lat, 4)} end)
        |> Stroke.path()

      %{author_id: author.id, color: color, points: path, trip_id: japan.id}
      |> Sketch.new()
      |> DB.create!()
    end

    # A hand-drawn circle around a place, `rx` by `ry` pixels on a 1920 by 1080 screen, starting
    # at the top and going clockwise, with a small wobble so it reads as a hand's circle and not
    # a compass's. Asked for in pixels because Japan's box is far wider in longitude than in
    # latitude, so equal radii in degrees would come out as a tall thin ellipse.
    ring = fn {lat, lng}, rx, ry, count ->
      japan_map = basemaps["japan"]

      r_lng = rx / 1920 * (japan_map.max_lng - japan_map.min_lng)
      r_lat = ry / 1080 * (japan_map.max_lat - japan_map.min_lat)

      for i <- 0..count do
        angle = i / count * 2 * :math.pi()
        wobble = 1 + 0.06 * :math.sin(angle * 3)

        {lat + r_lat * wobble * :math.cos(angle), lng + r_lng * wobble * :math.sin(angle)}
      end
    end

    # A straight run of `count` points from one place to another.
    line = fn {lat1, lng1}, {lat2, lng2}, count ->
      for i <- 0..count do
        t = i / count

        {lat1 + (lat2 - lat1) * t, lng1 + (lng2 - lng1) * t}
      end
    end

    ink.(people.bart, "#30b0c7", ring.({34.9671, 135.7727}, 78, 66, 44))
    ink.(people.bart, "#30b0c7", ring.({36.1408, 137.2520}, 62, 54, 40))

    haneda = {35.5494, 139.7798}
    ryokan = {35.2324, 139.1069}

    # The shaft, then the head: back up-and-right, back to the tip, back up-and-left.
    arrow =
      line.(haneda, ryokan, 24) ++
        line.(ryokan, {35.38, 139.18}, 5) ++
        line.({35.38, 139.18}, ryokan, 5) ++
        line.(ryokan, {35.30, 139.33}, 5)

    ink.(people.emilia, "#007aff", arrow)

    Mix.shell().info("+ Bart's circles around Kyoto and Takayama, Emilia's arrow to the ryokan")
end
