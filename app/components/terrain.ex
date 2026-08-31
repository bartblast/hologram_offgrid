defmodule Offgrid.Components.Terrain do
  use Hologram.Component

  @moduledoc """
  The map background: land, parks, a river, a road grid and one arterial.

  A stylised stand-in for real cartography. Every colour comes from a token, so the
  terrain follows the theme. The 900x520 viewBox is slice-scaled, so the drawing
  keeps its proportions and crops rather than stretching.
  """

  def template do
    ~HOLO"""
    <svg class="terrain" viewBox="0 0 900 520" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
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
    """
  end
end
