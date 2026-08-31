defmodule HologramSkeleton.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HologramSkeletonWeb.Telemetry,
      # HologramSkeleton.Repo,
      {DNSCluster, query: Application.get_env(:hologram_skeleton, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HologramSkeleton.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: HologramSkeleton.Finch},
      # Start a worker by calling: HologramSkeleton.Worker.start_link(arg)
      # {HologramSkeleton.Worker, arg},
      # Start to serve requests, typically the last entry
      HologramSkeletonWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HologramSkeleton.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HologramSkeletonWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
