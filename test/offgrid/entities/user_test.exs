defmodule Offgrid.Entities.UserTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.User, only: [new: 1]

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

    test "refuses a name that is not a string" do
      user = new(email: "anna@example.com", name: :anna, password_hash: "$2b$12$hash")

      assert Entity.validate(user) == {:error, %{name: [{:type, :string}]}}
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
end
