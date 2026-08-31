defmodule HologramSkeleton.Repo do
  use Ecto.Repo,
    otp_app: :hologram_skeleton,
    adapter: Ecto.Adapters.Postgres
end
