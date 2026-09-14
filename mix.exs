defmodule Offgrid.MixProject do
  use Mix.Project

  def project do
    [
      app: :offgrid,
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: Mix.compilers() ++ [:hologram]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Offgrid.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["app", "lib", "test/support"]
  defp elixirc_paths(_), do: ["app", "lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.20"},
      # Phoenix renders its HTML error pages through Phoenix.HTML's engine.
      {:phoenix_html, "~> 4.1"},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:bcrypt_elixir, "~> 3.0"},
      {:wallaby, "~> 0.30", only: :test},
      {:hologram, github: "bartblast/hologram", ref: "dcd4885cef91d5f98e715abd868376a68148a62f"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      # Hologram stays off in dev and test unless HOLOGRAM_START is set, and the seeds write
      # through it.
      seed: [fn _args -> System.put_env("HOLOGRAM_START", "1") end, "run priv/seeds.exs"],
      # assets.build, because feature tests serve the built stylesheet: without it a CSS change
      # is invisible to them and they fail describing something else entirely.
      test: ["assets.build", "test"],
      "assets.setup": ["tailwind.install --if-missing"],
      "assets.build": ["tailwind offgrid"],
      "assets.deploy": ["tailwind offgrid --minify", "phx.digest"]
    ]
  end
end
