defmodule Offgrid.Features.CommentsTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.User

  setup do
    truncate_trip_data()

    trip = create_trip()

    stop =
      %{date: ~D[2026-03-29], name: "Ryokan", trip_id: trip.id}
      |> Stop.new()
      |> DB.create!()

    [stop: stop, trip: trip]
  end

  feature "shows a stop's remarks in the order they were left", %{
    session: session,
    stop: stop,
    trip: trip
  } do
    tom = person("Tom Reyes", "tom@offgrid.test")
    anna = person("Anna Kim", "anna@offgrid.test")

    # Tom spoke first, so his remark is first whatever the alphabet says.
    remark(tom, stop, "Onsen booked. Dinner is not, someone call them before Friday")
    remark(anna, stop, "I can call tomorrow morning")

    session =
      session
      |> sign_in_as_member(trip)
      |> click(css(".stop", text: "Ryokan"))
      |> assert_has(css(".cmt", count: 2))
      # Upper case because `.cmt b` is text-transform: uppercase and a browser reports the
      # text it rendered - the same trap the roles and the map thumbs set.
      |> assert_text(css(".cmt", at: 0), "TOM REYES")
      |> assert_text(css(".cmt", at: 0), "Onsen booked")
      |> assert_text(css(".cmt", at: 1), "ANNA KIM")
      |> assert_text(css(".cmt", at: 1), "I can call tomorrow morning")

    # Coloured by the order they first spoke here: Tom first, Anna second.
    session |> find(css(".cmt", at: 0)) |> assert_has(css("i.a"))
    session |> find(css(".cmt", at: 1)) |> assert_has(css("i.t"))

    # The clock reads as this browser reads it, not as the server wrote it: the row holds
    # UTC, and the screen shows it shifted by the offset the browser itself reports.
    [first] =
      Comment
      |> filter(body: "Onsen booked. Dinner is not, someone call them before Friday")
      |> DB.read()

    assert_text(session, css(".cmt", at: 0), local_clock(session, first.created_at))
  end

  # "HH:MM" of the given UTC moment in the browser's own time zone, computed the way the
  # panel does - so the assertion holds wherever the machine running it is.
  defp local_clock(session, at) do
    execute_script(session, "return new Date().getTimezoneOffset()", fn offset ->
      send(self(), {:offset, offset})
    end)

    offset =
      receive do
        {:offset, offset} -> trunc(offset)
      after
        5_000 -> flunk("the browser never answered its offset")
      end

    minutes = Integer.mod(at.hour * 60 + at.minute - offset, 1_440)
    "#{pad(div(minutes, 60))}:#{pad(rem(minutes, 60))}"
  end

  defp pad(number) when number < 10, do: "0#{number}"

  defp pad(number), do: "#{number}"

  feature "leaves a remark from the editor, which shows before it travels", %{
    session: session,
    stop: stop,
    trip: trip
  } do
    remark(person("Tom Reyes", "tom@offgrid.test"), stop, "Onsen booked.")

    session =
      session
      |> sign_in_as_member(trip)
      |> click(css(".stop", text: "Ryokan"))
      |> assert_has(css(".cmt", count: 1))
      # Enter on an empty field leaves nothing behind.
      |> click(css(".editor .inp", at: 2))
      |> send_keys([:enter])
      |> assert_has(css(".cmt", count: 1))
      |> fill_in(css(".editor .inp", at: 2), with: "I can call tomorrow morning")
      |> send_keys([:enter])
      # Appended after Tom's, signed by whoever is typing, in their own colour - and the field
      # is empty again for the next one.
      |> assert_has(css(".cmt", count: 2))
      |> assert_text(css(".cmt", at: 1), "NORA VALE")
      |> assert_text(css(".cmt", at: 1), "I can call tomorrow morning")

    session |> find(css(".cmt", at: 1)) |> assert_has(css("i.y"))
    assert session |> find(css(".editor .inp", at: 2)) |> Wallaby.Element.value() == ""

    # It was a row, not a screen: read back from the server, with the author the gate pinned.
    await_pending_writes(session, 0)

    [comment] =
      Comment
      |> filter(body: "I can call tomorrow morning")
      |> include(:author)
      |> DB.read()

    assert comment.author.email == "member@offgrid.test"
  end

  feature "starts a new stop with an empty remark box", %{session: session, trip: trip} do
    %{date: ~D[2026-03-30], name: "Fushimi Inari", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    session =
      session
      |> sign_in_as_member(trip)
      |> click(css(".stop", text: "Ryokan"))
      |> fill_in(css(".editor .inp", at: 2), with: "Onsen booked, dinner is not")
      |> click(css(".stop", text: "Fushimi Inari"))
      |> assert_text(css(".ed-title"), "Fushimi Inari")

    # The half-written remark was Ryokan's. The panel keeps its state from one stop to the
    # next, so the draft has to know which stop it was for.
    assert session |> find(css(".editor .inp", at: 2)) |> Wallaby.Element.value() == ""
  end

  feature "deleting a stop removes its remarks too", %{session: session, stop: stop, trip: trip} do
    remark(person("Tom Reyes", "tom@offgrid.test"), stop, "Onsen booked.")

    session
    |> sign_in_as_member(trip)
    |> click(css(".stop", text: "Ryokan"))
    |> assert_has(css(".cmt", count: 1))
    |> click(button("Delete stop"))
    |> refute_has(css(".editor"))
    |> await_pending_writes(0)

    # A remark names its stop and the reference restricts rather than cascades, so a stop
    # deleted on its own is refused by the server however cleanly the browser showed it gone.
    # Both rows have to leave, and the server is the only witness that they did.
    assert DB.read(Stop) == []
    assert DB.read(Comment) == []
  end

  defp person(name, email) do
    %{email: email, name: name, password_hash: "x"}
    |> User.new()
    |> DB.create!()
  end

  defp remark(author, stop, body) do
    %{author_id: author.id, body: body, stop_id: stop.id}
    |> Comment.new()
    |> DB.create!()
  end
end
