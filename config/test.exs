import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :offgrid, Offgrid.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "offgrid_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Hologram's data layer owns its own connection to the same Postgres server, separate
# from Ecto's.
config :hologram, :database,
  database: "offgrid_test#{System.get_env("MIX_TEST_PARTITION")}",
  host: "localhost",
  password: "postgres",
  user: "postgres"

# The server runs during test because the feature tests drive a real browser against it.
config :offgrid, OffgridWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "LcC86i/is+nf1SYJGqwN4sWCTaSM3uRv0i1EhTv7JbpElGX+r7QKvyHKX+0o3NhB",
  server: true

# In test we don't send emails
config :offgrid, Offgrid.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :wallaby,
  chromedriver: [
    capabilities: %{
      chromeOptions: %{
        args: [
          "--disable-background-timer-throttling",
          "--disable-dev-shm-usage",
          "--disable-gpu",
          "--headless",
          "--no-sandbox",
          "--window-size=1280,800"
        ]
      }
    },
    # The default 10s is not always enough for chromedriver to come up.
    readiness_timeout: 60_000
  ],
  driver: Wallaby.Chrome,
  hackney_options: [timeout: 60_000, recv_timeout: 60_000],
  max_wait_time: 30_000,
  # No :otp_app on purpose. Wallaby uses it for one thing only - checking the app's Ecto
  # repos out into the SQL sandbox - and the data under test is Hologram's, which holds its
  # own connection and knows nothing about that sandbox.
  screenshot_dir: "./tmp/screenshots",
  screenshot_on_failure: true
