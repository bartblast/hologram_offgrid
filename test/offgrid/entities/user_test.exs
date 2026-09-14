defmodule Offgrid.Entities.UserTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.User,
    only: [hash_password: 1, initials: 1, new: 1, valid_password?: 2]

  alias Hologram.Entity
  alias Offgrid.Entities.User

  describe "Entity.server_only_attribute_names/1" do
    test "keeps the password hash off the client" do
      assert Entity.server_only_attribute_names(User) == [:password_hash]
    end
  end

  describe "Entity.validate/1" do
    test "accepts a complete user" do
      user = new(email: "anna@example.com", name: "Anna", password_hash: "$2b$12$hash")

      assert Entity.validate(user) == :ok
    end

    test "refuses a missing email" do
      user = new(name: "Anna", password_hash: "$2b$12$hash")

      assert Entity.validate(user) == {:error, %{email: [:required]}}
    end

    test "refuses an empty email" do
      user = new(email: "", name: "Anna", password_hash: "$2b$12$hash")

      assert Entity.validate(user) == {:error, %{email: [{:min_length, 1}]}}
    end

    test "refuses an empty name" do
      user = new(email: "anna@example.com", name: "", password_hash: "$2b$12$hash")

      assert Entity.validate(user) == {:error, %{name: [{:min_length, 1}]}}
    end

    test "refuses a name that is not a string" do
      user = new(email: "anna@example.com", name: :anna, password_hash: "$2b$12$hash")

      assert Entity.validate(user) == {:error, %{name: [{:type, :string}]}}
    end
  end

  describe "hash_password/1" do
    test "salts, so the same password hashes differently each time" do
      assert hash_password("japan-2026") != hash_password("japan-2026")
    end
  end

  describe "initials/1" do
    test "takes the first letter of the first two words" do
      assert initials(new(name: "Nora Vale")) == "NV"
    end

    test "takes one letter from a one-word name" do
      assert initials(new(name: "Bart")) == "B"
    end

    test "ignores a third word and extra spaces" do
      assert initials(new(name: "  Anna  Maria Kim ")) == "AM"
    end
  end

  describe "new/1" do
    test "holds every attribute it was given" do
      user = new(email: "anna@example.com", name: "Anna", password_hash: "$2b$12$hash")

      assert %User{
               email: "anna@example.com",
               name: "Anna",
               password_hash: "$2b$12$hash",
               created_at: nil,
               updated_at: nil
             } = user

      assert is_binary(user.id)
    end
  end

  describe "valid_password?/2" do
    setup do
      [user: new(password_hash: hash_password("japan-2026"))]
    end

    test "accepts the user's password", %{user: user} do
      assert valid_password?(user, "japan-2026")
    end

    test "refuses another password", %{user: user} do
      refute valid_password?(user, "japan-2025")
    end

    test "refuses any password when there is no user" do
      refute valid_password?(nil, "japan-2026")
    end
  end
end
