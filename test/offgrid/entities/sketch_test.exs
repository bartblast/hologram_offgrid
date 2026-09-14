defmodule Offgrid.Entities.SketchTest do
  # Not async: the Auth.can?/3 checks empty the database, which other modules write too.
  use ExUnit.Case, async: false

  import Offgrid.Entities.Sketch, only: [new: 1]
  import Offgrid.FeatureHelpers, only: [create_trip: 0, create_user: 2, reset_data: 0]

  alias Hologram.Auth
  alias Hologram.Entity
  alias Offgrid.Entities.Sketch

  @author_id "01a05d36-4826-77cc-b885-6bb4a30a5ba5"
  @path "M135.7681,-35.0116 L139.6503,-35.6762"
  @trip_id "01a05d99-76cf-73b7-bf0e-4045ea59b4f1"

  describe "Auth.can?/3" do
    # The rules read grants from the database, which only the feature run boots.
    @describetag :feature

    setup do
      reset_data()

      [trip: create_trip(), user: create_user("Nora Vale", "nora@offgrid.test")]
    end

    test "lets a member draw on their trip", %{trip: trip, user: user} do
      :ok = Auth.grant_role(user, trip, :member)

      sketch = new(author_id: user.id, color: "#ff2d55", path: @path, trip_id: trip.id)

      assert Auth.can?(user, :create, sketch)
    end

    test "refuses somebody with no role on the trip", %{trip: trip, user: user} do
      sketch = new(author_id: user.id, color: "#ff2d55", path: @path, trip_id: trip.id)

      refute Auth.can?(user, :create, sketch)
    end

    test "refuses a member drawing in somebody else's name", %{trip: trip, user: user} do
      :ok = Auth.grant_role(user, trip, :member)
      other = create_user("Tom Reyes", "tom@offgrid.test")

      sketch = new(author_id: other.id, color: "#ff2d55", path: @path, trip_id: trip.id)

      refute Auth.can?(user, :create, sketch)
    end
  end

  describe "Entity.validate/1" do
    test "accepts a complete sketch" do
      sketch = new(author_id: @author_id, color: "#ff2d55", path: @path, trip_id: @trip_id)

      assert Entity.validate(sketch) == :ok
    end

    test "refuses a stroke with no path" do
      sketch = new(author_id: @author_id, color: "#ff2d55", trip_id: @trip_id)

      assert Entity.validate(sketch) == {:error, %{path: [:required]}}
    end

    test "refuses a stroke with no colour" do
      sketch = new(author_id: @author_id, path: @path, trip_id: @trip_id)

      assert Entity.validate(sketch) == {:error, %{color: [:required]}}
    end

    test "refuses a stroke with no author" do
      sketch = new(color: "#ff2d55", path: @path, trip_id: @trip_id)

      assert Entity.validate(sketch) == {:error, %{author_id: [:required]}}
    end

    test "refuses a stroke on no trip" do
      sketch = new(author_id: @author_id, color: "#ff2d55", path: @path)

      assert Entity.validate(sketch) == {:error, %{trip_id: [:required]}}
    end
  end

  describe "new/1" do
    test "holds the stroke as it was given" do
      sketch = new(author_id: @author_id, color: "#ff2d55", path: @path, trip_id: @trip_id)

      assert %Sketch{
               author_id: @author_id,
               color: "#ff2d55",
               path: @path,
               trip_id: @trip_id,
               created_at: nil,
               updated_at: nil
             } = sketch

      assert is_binary(sketch.id)
    end
  end
end
