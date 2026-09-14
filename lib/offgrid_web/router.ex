defmodule OffgridWeb.Router do
  # No routes of its own. Every page this app serves is a Hologram page, and `Hologram.Router`
  # is plugged ahead of this one in the endpoint - a request that gets this far matched no page,
  # and is answered by the error views.
  use Phoenix.Router, helpers: false
end
