defmodule Offgrid.Entities.CommentTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.Comment, only: [new: 1]

  alias Hologram.Entity
  alias Offgrid.Entities.Comment

  @author_id "01a05d36-4826-77cc-b885-6bb4a30a5ba5"
  @stop_id "01a05d38-ffc6-7db6-8bc1-152cf7dca119"

  describe "Entity.validate/1" do
    test "accepts a complete comment" do
      comment =
        new(
          author_id: @author_id,
          body: "Go before eight, the crowds come at nine.",
          stop_id: @stop_id
        )

      assert Entity.validate(comment) == :ok
    end

    test "refuses a missing body" do
      comment = new(author_id: @author_id, stop_id: @stop_id)

      assert Entity.validate(comment) == {:error, %{body: [:required]}}
    end

    test "refuses a comment with no author" do
      comment = new(body: "Go before eight.", stop_id: @stop_id)

      assert Entity.validate(comment) == {:error, %{author_id: [:required]}}
    end

    test "refuses a comment on no stop" do
      comment = new(author_id: @author_id, body: "Go before eight.")

      assert Entity.validate(comment) == {:error, %{stop_id: [:required]}}
    end
  end

  describe "new/1" do
    test "holds what it was given and nothing else" do
      comment = new(author_id: @author_id, body: "Go before eight.", stop_id: @stop_id)

      assert %Comment{
               author_id: @author_id,
               body: "Go before eight.",
               stop_id: @stop_id,
               created_at: nil,
               updated_at: nil
             } = comment

      assert is_binary(comment.id)
    end
  end
end
