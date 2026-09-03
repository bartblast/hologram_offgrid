defmodule Offgrid.Components.Terrain do
  use Hologram.Component
  use Hologram.DB

  alias Offgrid.Entities.Trip

  @moduledoc """
  The map background, drawn for whichever basemap the trip is on.

  Stylised stand-ins for real cartography rather than drawings of anywhere. Every colour comes
  from a token, so the terrain follows the theme, and each 900x520 viewBox is slice-scaled, so
  a drawing keeps its proportions and crops rather than stretching. The same three shapes
  appear as thumbnails in `BasemapThumb` - one map at two sizes.

  Without a trip there is nothing to look up, and the screen gets the app's backdrop: the
  trips list, the log-in card and the sign-up card all sit over the same city.
  """

  prop :trip, Trip, from_query: &trip_query/1
  prop :trip_id, :string, default: nil

  # init/2, because a Link from one trip to another mounts this on the client.
  def init(_props, component), do: component

  def template do
    ~HOLO"""
    {%if slug(@trip) == "warsaw"}
      <svg class="terrain warsaw" viewBox="0 0 900 520" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
        <rect width="900" height="520" fill="var(--land)" />
        <path
          d="M320 0 C340 70, 300 165, 360 260 C440 355, 380 425, 400 520 L520 520 C500 485, 540 437, 480 355 C400 260, 460 140, 380 0 Z"
          fill="var(--water)"
        />
        <g stroke="var(--roadline)" stroke-width="10" fill="none">
          <path d="M60 140 H300 M80 300 H320 M40 420 H360 M140 40 V480 M240 40 V480" />
          <path d="M580 100 H860 M560 240 H840 M600 380 H880 M700 40 V480 M800 40 V480" />
        </g>
        <g stroke="var(--road)" stroke-width="7" fill="none">
          <path d="M60 140 H300 M80 300 H320 M40 420 H360 M140 40 V480 M240 40 V480" />
          <path d="M580 100 H860 M560 240 H840 M600 380 H880 M700 40 V480 M800 40 V480" />
        </g>
      </svg>
    {/if}

    {%if slug(@trip) == "alps"}
      <svg class="terrain alps" viewBox="0 0 900 520" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
        <rect width="900" height="520" fill="var(--water)" />
        <path
          d="M120 448 C180 236, 280 94, 450 83 C630 71, 740 212, 800 425 C700 496, 220 507, 120 448 Z"
          fill="var(--land)"
          stroke="var(--line2)"
          stroke-width="3"
        />
        <g stroke="var(--line2)" stroke-width="2" fill="none">
          <path d="M300 430 C340 320, 390 240, 450 180 C510 240, 560 320, 600 430" />
          <path d="M200 440 C240 370, 280 320, 330 280" />
          <path d="M570 280 C620 330, 660 380, 700 440" />
        </g>
      </svg>
    {/if}

    {%if slug(@trip) == "japan"}
      <svg class="terrain japan" viewBox="0 0 900 520" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
      <rect width="900" height="520" fill="var(--land)" />
      <path d="M96 62 h150 v104 h-150 z" fill="var(--park)" />
      <path d="M648 96 q64 -18 92 34 q22 60 -40 82 q-70 16 -92 -40 q-16 -52 40 -76 z" fill="var(--park)" />
      <path d="M300 248 h118 v68 h-118 z" fill="var(--park)" />
      <path
        d="M-20 372 C120 348, 220 396, 360 386 C500 376, 600 410, 720 396 C812 386, 880 398, 920 392 L920 452 C860 458, 800 448, 720 456 C600 468, 500 436, 360 446 C230 456, 110 414, -20 436 Z"
        fill="var(--water)"
      />
      <g stroke="var(--roadline)" stroke-width="12" fill="none">
        <path d="M0 120 H900 M0 232 H900 M0 316 H900 M164 0 V520 M392 0 V520 M596 0 V352 M772 0 V352" />
      </g>
      <g stroke="var(--road)" stroke-width="9" fill="none">
        <path d="M0 120 H900 M0 232 H900 M0 316 H900 M164 0 V520 M392 0 V520 M596 0 V352 M772 0 V352" />
      </g>
      <path d="M0 58 L272 58 L516 188 L900 188" stroke="var(--arterialline)" stroke-width="16" fill="none" />
      <path d="M0 58 L272 58 L516 188 L900 188" stroke="var(--arterial)" stroke-width="12" fill="none" />
    </svg>
    {/if}
    """
  end

  # The app's backdrop when no trip is named, and when the one named is not this person's to
  # read - the query answers nothing either way, and a screen with no map behind it would be
  # a stranger sight than a city.
  defp slug(nil), do: "japan"

  defp slug(trip), do: trip.basemap.slug

  defp trip_query(trip_id) do
    Trip
    |> filter(id: trip_id)
    |> include(:basemap)
    |> one()
  end
end
