defmodule Offgrid.Entities.SketchTest do
  use ExUnit.Case, async: true

  import Offgrid.Entities.Sketch, only: [new: 1]

  alias Hologram.Entity
  alias Offgrid.Entities.Sketch

  @author_id "01a05d36-4826-77cc-b885-6bb4a30a5ba5"
  @points "35.0116,135.7681 35.6762,139.6503"
  @trip_id "01a05d99-76cf-73b7-bf0e-4045ea59b4f1"

  describe "Entity.validate/1" do
    test "accepts a complete sketch" do
      sketch = new(author_id: @author_id, color: "#ff2d55", points: @points, trip_id: @trip_id)

      assert Entity.validate(sketch) == :ok
    end

    test "refuses a stroke with no points" do
      sketch = new(author_id: @author_id, color: "#ff2d55", trip_id: @trip_id)

      assert Entity.validate(sketch) == {:error, %{points: [:required]}}
    end

    test "refuses a stroke with no colour" do
      sketch = new(author_id: @author_id, points: @points, trip_id: @trip_id)

      assert Entity.validate(sketch) == {:error, %{color: [:required]}}
    end

    test "refuses a stroke with no author" do
      sketch = new(color: "#ff2d55", points: @points, trip_id: @trip_id)

      assert Entity.validate(sketch) == {:error, %{author_id: [:required]}}
    end

    test "refuses a stroke on no trip" do
      sketch = new(author_id: @author_id, color: "#ff2d55", points: @points)

      assert Entity.validate(sketch) == {:error, %{trip_id: [:required]}}
    end
  end

  describe "new/1" do
    test "holds the stroke as it was given" do
      sketch = new(author_id: @author_id, color: "#ff2d55", points: @points, trip_id: @trip_id)

      assert %Sketch{
               author_id: @author_id,
               color: "#ff2d55",
               points: @points,
               trip_id: @trip_id,
               created_at: nil,
               updated_at: nil
             } = sketch

      assert is_binary(sketch.id)
    end
  end
end
