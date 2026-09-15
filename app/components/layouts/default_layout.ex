defmodule Offgrid.Components.DefaultLayout do
  @moduledoc """
  The HTML document every page renders into: the stylesheet, the Inter fallback font, and the
  Hologram runtime.
  """

  use Hologram.Component

  alias Hologram.UI.Runtime

  def template do
    ~HOLO"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Offgrid</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
        />
        <link rel="stylesheet" href={asset_path("assets/app.css")} />
        <Runtime />
      </head>
      <body>
        <slot />
      </body>
    </html>
    """
  end
end
