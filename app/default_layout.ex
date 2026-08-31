defmodule Offgrid.DefaultLayout do
  use Hologram.Component
  
  def template do
    ~HOLO"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>Offgrid</title>
        <Hologram.UI.Runtime />
      </head>
      <body>
        <slot />
      </body>
    </html>
    """
  end
end
