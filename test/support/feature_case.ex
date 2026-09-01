defmodule Offgrid.FeatureCase do
  use ExUnit.CaseTemplate

  alias Hologram.Test.FeatureHelpers

  @moduledoc """
  The case for tests that drive a real browser against the running app.

      defmodule Offgrid.Features.SomethingTest do
        use Offgrid.FeatureCase, async: false

        feature "does something", %{session: session} do
          session
          |> visit(TripPage)
          |> click(button("Add a stop"))
          |> assert_text(css(".editor"), "New stop")
        end
      end

  Every test here is tagged `:feature`, which the default `mix test` run excludes -
  `mix test --only feature` runs them.

  A test needing more than one browser says so with `@sessions 2` and receives
  `%{sessions: [one, two]}` in place of `%{session: session}`, which is how both halves of
  a sync get watched at once.

  `visit/2` is Hologram's, which takes a page module rather than a URL and waits for the
  client runtime to finish mounting. `assert_text/3` is `Offgrid.FeatureHelpers`', which
  stays pipeable.
  """

  using do
    quote do
      ExUnit.Case.register_attribute(__MODULE__, :sessions)

      @moduletag :feature

      # Wallaby.Browser.tap/2 taps an element, and would otherwise be ambiguous with
      # Kernel.tap/2.
      import Kernel, except: [tap: 2]

      import Hologram.Test.FeatureHelpers
      import Offgrid.FeatureHelpers

      import Wallaby.Browser,
        except: [
          assert_text: 3,
          visit: 2
        ]

      import Wallaby.Feature
      import Wallaby.Query

      setup context do
        FeatureHelpers.start_sessions(context)
      end
    end
  end
end
