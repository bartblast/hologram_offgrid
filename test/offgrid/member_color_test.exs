defmodule Offgrid.MemberColorTest do
  use ExUnit.Case, async: true

  import Offgrid.MemberColor

  alias Hologram.Auth.RoleGrant
  alias Offgrid.Entities.User

  @bart "01a05d36-4826-77cc-b885-6bb4a30a5ba5"
  @anna "01a05d38-ffc6-7db6-8bc1-152cf7dca119"
  @tom "01a05d99-76cf-73b7-bf0e-4045ea59b4f1"
  @mira "01a05da1-1b2c-7d3e-8f40-5161728394a5"

  # Bart made the trip, then Anna, Tom and Mira joined, in that order. Bart holds two grants,
  # organizer and member.
  @grants [
    %RoleGrant{role: :organizer, user_id: @bart},
    %RoleGrant{role: :member, user_id: @anna},
    %RoleGrant{role: :member, user_id: @bart},
    %RoleGrant{role: :member, user_id: @tom},
    %RoleGrant{role: :member, user_id: @mira}
  ]

  describe "of/3" do
    test "you are always your own colour" do
      assert of(@grants, @tom, @tom) == "y"
    end

    test "the first other member is violet and the second teal" do
      assert of(@grants, @bart, @anna) == "a"
      assert of(@grants, @bart, @tom) == "t"
    end

    test "anyone after the second is grey" do
      assert of(@grants, @bart, @mira) == ""
    end

    test "skips you when counting the others" do
      # On Anna's screen Bart is first and Tom second - Anna herself is not in the count.
      assert of(@grants, @anna, @bart) == "a"
      assert of(@grants, @anna, @tom) == "t"
      assert of(@grants, @anna, @mira) == ""
    end

    test "counts a person with several grants once" do
      # On Anna's screen, Bart's second grant must not push Tom from second to third.
      assert of(@grants, @anna, @tom) == "t"
    end

    test "somebody not on the trip is grey" do
      assert of(@grants, @bart, "01a05db0-0000-7000-8000-000000000000") == ""
    end

    test "with nobody signed in everyone is somebody else" do
      assert of(@grants, nil, @bart) == "a"
      assert of(@grants, nil, @anna) == "t"
    end

    test "colours invited users in the order they were added" do
      invites = [User.new(id: @anna), User.new(id: @tom)]

      assert of(invites, nil, @anna) == "a"
      assert of(invites, nil, @tom) == "t"
    end
  end
end
