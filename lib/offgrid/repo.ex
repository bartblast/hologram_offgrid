defmodule Offgrid.Repo do
  use Ecto.Repo,
    otp_app: :offgrid,
    adapter: Ecto.Adapters.Postgres
end
