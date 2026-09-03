defmodule Offgrid.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Offgrid.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Offgrid.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Offgrid.DataCase
    end
  end

  setup tags do
    Offgrid.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags, when there is a repo to set it up against.

  `Offgrid.Repo` is commented out of the supervision tree while Hologram's own data layer is
  what this app stores anything in, so a checkout here would raise before a test that never
  touches Ecto had begun - which is what the error view tests were doing. This changes nothing
  once the repo is started again: it is only absent that it steps aside.
  """
  def setup_sandbox(tags) do
    if Process.whereis(Offgrid.Repo) do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Offgrid.Repo, shared: not tags[:async])
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
