# Feature tests drive a real browser and take far longer than the rest of the suite, so
# they are excluded by default. `mix test` runs the unit tests, `mix test --only feature`
# runs the browser ones. Everything the browser needs - the Hologram compile, a converged
# schema, chromedriver - is booted below only when they are actually included, which keeps
# the unit run as fast as it was before this file grew.
ExUnit.start(exclude: [:feature])
# Ecto.Adapters.SQL.Sandbox.mode(Offgrid.Repo, :manual)

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
