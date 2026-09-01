defmodule Offgrid.Components.BasemapThumb do
  use Hologram.Component

  @moduledoc """
  A map in miniature, named by its slug.

  The three shapes are the mockup's own, unchanged - they are stand-ins for real
  cartography rather than drawings of anywhere, which is why they can be this crude and
  still read as Japan, a city and a mountain range. Every colour comes from a token, so a
  thumbnail and the full-size terrain behind it are the same map at two sizes.
  """

  prop :slug, :string

  def template do
    ~HOLO"""
    {%if @slug == "japan"}
      <svg class="thumb-svg" viewBox="0 0 90 44" aria-hidden="true">
        <rect width="90" height="44" fill="var(--land)" />
        <rect x="8" y="6" width="20" height="13" fill="var(--park)" />
        <path
          d="M0 30 C18 26, 34 34, 52 30 C70 26, 82 32, 90 30 L90 38 C80 40, 68 34, 52 38 C34 42, 16 34, 0 38 Z"
          fill="var(--water)"
        />
        <g stroke="var(--road)" stroke-width="2.5" fill="none">
          <path d="M0 12 H90 M0 24 H90 M22 0 V44 M52 0 V44 M72 0 V26" />
        </g>
      </svg>
    {/if}

    {%if @slug == "warsaw"}
      <svg class="thumb-svg" viewBox="0 0 90 44" aria-hidden="true">
        <rect width="90" height="44" fill="var(--land)" />
        <path
          d="M38 0 C46 12, 40 22, 48 30 C54 37, 50 41, 52 44 L40 44 C38 36, 44 30, 36 22 C30 14, 34 6, 32 0 Z"
          fill="var(--water)"
        />
        <g stroke="var(--line2)" stroke-width="1">
          <path d="M6 12 H30 M8 26 H32 M4 36 H36 M58 8 H86 M56 20 H84 M60 32 H88 M14 4 V40 M70 4 V40" />
        </g>
      </svg>
    {/if}

    {%if @slug == "alps"}
      <svg class="thumb-svg" viewBox="0 0 90 44" aria-hidden="true">
        <rect width="90" height="44" fill="var(--water)" />
        <path
          d="M12 38 C18 20, 28 8, 45 7 C63 6, 74 18, 80 36 C70 42, 22 43, 12 38 Z"
          fill="var(--land)"
          stroke="var(--line2)"
        />
      </svg>
    {/if}
    """
  end
end
