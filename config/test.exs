import Config

# Hologram's data layer, holding every row the app stores.
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
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

# The cheapest hash bcrypt allows. The suite hashes a password for every account it creates.
config :bcrypt_elixir, log_rounds: 1

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :wallaby,
  chromedriver: [
    capabilities: %{
      chromeOptions: %{
        args: [
          "--disable-background-timer-throttling",
          # The stylesheet drops the panel slide and its transitions for reduced motion, so a
          # test never clicks inside a panel that is still moving.
          "--force-prefers-reduced-motion",
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
  # repos out into the SQL sandbox - and the app has no Ecto repos.
  screenshot_dir: "./tmp/screenshots",
  screenshot_on_failure: true
