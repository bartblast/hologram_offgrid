defmodule Offgrid.PasswordTest do
  use ExUnit.Case, async: true

  import Offgrid.Password

  alias Offgrid.Entities.User

  describe "hash/1" do
    test "salts, so the same password hashes differently each time" do
      assert hash("japan-2026") != hash("japan-2026")
    end
  end

  describe "valid?/2" do
    setup do
      [user: User.new(password_hash: hash("japan-2026"))]
    end

    test "accepts the user's password", %{user: user} do
      assert valid?(user, "japan-2026")
    end

    test "refuses another password", %{user: user} do
      refute valid?(user, "japan-2025")
    end

    test "refuses any password when there is no user" do
      refute valid?(nil, "japan-2026")
    end
  end
end
