defmodule Offgrid.PresenceTest do
  use ExUnit.Case, async: true

  import Offgrid.Presence

  @anna %{id: "anna", initials: "AK"}
  @tom %{id: "tom", initials: "TR"}

  describe "arrive/2" do
    test "adds somebody new at the end" do
      assert arrive([@anna], @tom) == [@anna, @tom]
    end

    test "adds somebody already here only once" do
      assert arrive([@anna, @tom], @anna) == [@anna, @tom]
    end
  end

  describe "cursor/2" do
    test "starts a person's sequence at one" do
      assert cursor(%{}, %{id: "anna", initials: "AK", x: 10.0, y: 20.0}) ==
               {%{"anna" => %{initials: "AK", seq: 1, x: 10.0, y: 20.0}}, 1}
    end

    test "bumps the sequence per person, not per screen" do
      {cursors, 1} = cursor(%{}, %{id: "anna", initials: "AK", x: 10.0, y: 20.0})
      {cursors, 1} = cursor(cursors, %{id: "tom", initials: "TR", x: 30.0, y: 40.0})
      {cursors, 2} = cursor(cursors, %{id: "anna", initials: "AK", x: 11.0, y: 21.0})

      assert cursors["anna"] == %{initials: "AK", seq: 2, x: 11.0, y: 21.0}
      assert cursors["tom"].seq == 1
    end
  end

  describe "expire/3" do
    setup do
      {cursors, seq} = cursor(%{}, %{id: "anna", initials: "AK", x: 10.0, y: 20.0})
      [cursors: cursors, seq: seq]
    end

    test "drops the cursor when nothing newer arrived", %{cursors: cursors, seq: seq} do
      assert expire(cursors, "anna", seq) == %{}
    end

    test "keeps the cursor when a newer position arrived", %{cursors: cursors, seq: seq} do
      {cursors, _newer} = cursor(cursors, %{id: "anna", initials: "AK", x: 11.0, y: 21.0})

      assert expire(cursors, "anna", seq) == cursors
    end

    test "leaves a cursor that is already gone alone", %{cursors: cursors} do
      assert expire(cursors, "tom", 1) == cursors
    end
  end

  describe "edit/2" do
    test "records the stop and the field somebody has open" do
      editing = edit(%{}, %{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 1})

      assert editing == %{
               "anna" => %{field: "name", initials: "AK", seq: 1, stop_id: "ryokan"}
             }
    end

    test "a field of nil means the stop is open with nothing focused" do
      editing = edit(%{}, %{id: "anna", initials: "AK", stop_id: "ryokan", field: nil, seq: 1})

      assert editing["anna"].field == nil
    end

    test "a stop of nil means nothing open" do
      editing = edit(%{}, %{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 1})
      closed = edit(editing, %{id: "anna", initials: "AK", stop_id: nil, field: nil, seq: 2})

      assert closed["anna"].stop_id == nil
      assert on_stop(closed, "ryokan") == []
    end

    # Two messages sent a moment apart can arrive in the other order, so the one that lost the
    # race must not undo the one that won it.
    test "ignores a message older than one already heard from that person" do
      editing = edit(%{}, %{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 2})
      stale = edit(editing, %{id: "anna", initials: "AK", stop_id: "ryokan", field: nil, seq: 1})

      assert stale["anna"].field == "name"
    end

    test "ignores a repeat of a message already heard" do
      editing = edit(%{}, %{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 2})
      again = edit(editing, %{id: "anna", initials: "AK", stop_id: nil, field: nil, seq: 2})

      assert again["anna"].stop_id == "ryokan"
    end

    test "counts each person separately" do
      editing =
        %{}
        |> edit(%{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 5})
        |> edit(%{id: "tom", initials: "TR", stop_id: "ryokan", field: nil, seq: 1})

      assert editing["tom"].stop_id == "ryokan"
    end
  end

  describe "depart/4" do
    setup do
      present = [@anna, @tom]
      editing = edit(%{}, %{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 3})

      [editing: editing, present: present]
    end

    test "lets somebody go when nothing newer has been heard", %{editing: e, present: p} do
      assert depart(p, e, "anna", 3) == {[@tom], %{}}
    end

    test "keeps somebody who has spoken since the check was queued", %{editing: e, present: p} do
      newer = edit(e, %{id: "anna", initials: "AK", stop_id: nil, field: nil, seq: 4})

      assert depart(p, newer, "anna", 3) == {p, newer}
    end

    test "leaves somebody already gone alone", %{editing: e, present: p} do
      assert depart(p, e, "mira", 1) == {p, e}
    end
  end

  describe "on_stop/2 and on_field/3" do
    setup do
      editing =
        %{}
        |> edit(%{id: "anna", initials: "AK", stop_id: "ryokan", field: "name", seq: 1})
        |> edit(%{id: "tom", initials: "TR", stop_id: "ryokan", field: nil, seq: 1})
        |> edit(%{id: "mira", initials: "MV", stop_id: "fushimi", field: "name", seq: 1})

      [editing: editing]
    end

    test "on_stop lists everyone on that stop, whatever field", %{editing: editing} do
      assert Enum.sort_by(on_stop(editing, "ryokan"), & &1.id) == [
               %{field: "name", id: "anna", initials: "AK"},
               %{field: nil, id: "tom", initials: "TR"}
             ]
    end

    test "on_field lists only those in that field of that stop", %{editing: editing} do
      assert on_field(editing, "ryokan", "name") == [%{id: "anna", initials: "AK"}]
      assert on_field(editing, "ryokan", "description") == []
      assert on_field(editing, "fushimi", "name") == [%{id: "mira", initials: "MV"}]
    end
  end
end
