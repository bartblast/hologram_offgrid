# Feature tests drive a real browser and are excluded by default: `mix test` runs the unit
# tests, `mix test --only feature` the browser ones. What the browser needs is booted below
# only when they are included, so the unit run stays fast.
ExUnit.start(exclude: [:feature])

if :feature in ExUnit.configuration()[:include] do
  # Creates the test database when absent and drops the Hologram schemas, so every run
  # converges from scratch. Runs before anything connects a pool, and after ExUnit.start/1 -
  # that is how it recognizes the test env.
  Hologram.Test.DatabaseBootstrap.run!()

  # Compiles the app to JavaScript, restarts Hologram with its full supervisor tree, and
  # converges the database schema to the entities the app declares.
  Hologram.Test.setup()

  # Kill headless browsers orphaned by a hard-interrupted run. chromedriver launches Chrome
  # with --test-type=webdriver, so this matches only browsers Wallaby spawned, never a real
  # one. pkill is Unix-only, so the guard makes this a no-op rather than a crash elsewhere.
  case System.find_executable("pkill") do
    nil -> :ok
    pkill -> System.cmd(pkill, ["-f", "test-type=webdriver"])
  end

  {:ok, _apps} = Application.ensure_all_started(:wallaby)

  Application.put_env(:wallaby, :base_url, OffgridWeb.Endpoint.url())
end
