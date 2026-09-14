defmodule Offgrid.Features.CommentsTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Dates
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop
  alias Wallaby.Element

  setup do
    reset_data()

    trip = create_trip()
    stop = create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    [stop: stop, trip: trip]
  end

  feature "shows a stop's remarks in the order they were left", %{
    session: session,
    stop: stop,
    trip: trip
  } do
    tom = create_user("Tom Reyes", "tom@offgrid.test")
    anna = create_user("Anna Kim", "anna@offgrid.test")

    # Tom joined first, then Anna - which is what decides their colours, not who spoke first.
    :ok = Auth.grant_role(tom, trip, :member)
    :ok = Auth.grant_role(anna, trip, :member)

    # Tom spoke first, so his remark is first whatever the alphabet says.
    create_comment(tom, stop, "Onsen booked. Dinner is not, someone call them before Friday")
    create_comment(anna, stop, "I can call tomorrow morning")

    session =
      session
      |> sign_in(trip)
      |> click(css(".stop", text: "Ryokan"))
      |> assert_has(css(".cmt", count: 2))
      # Upper case because `.cmt b` is text-transform: uppercase and a browser reports the
      # text it rendered.
      |> assert_text(css(".cmt", at: 0), "TOM REYES")
      |> assert_text(css(".cmt", at: 0), "Onsen booked")
      |> assert_text(css(".cmt", at: 1), "ANNA KIM")
      |> assert_text(css(".cmt", at: 1), "I can call tomorrow morning")

    # Coloured by the cast - Tom the first other member, Anna the second.
    session
    |> find(css(".cmt", at: 0))
    |> assert_has(css("i.a"))

    session
    |> find(css(".cmt", at: 1))
    |> assert_has(css("i.t"))

    # The clock reads as this browser reads it, not as the server wrote it: the row holds
    # UTC, and the screen shows it shifted by the offset the browser itself reports.
    [first] =
      Comment
      |> filter(body: "Onsen booked. Dinner is not, someone call them before Friday")
      |> DB.read()

    assert_text(session, css(".cmt", at: 0), local_clock(session, first.created_at))
  end

  feature "leaves a remark from the editor, which shows before it travels", %{
    session: session,
    stop: stop,
    trip: trip
  } do
    create_comment(create_user("Tom Reyes", "tom@offgrid.test"), stop, "Onsen booked.")

    session =
      session
      |> sign_in(trip)
      |> click(css(".stop", text: "Ryokan"))
      |> assert_has(css(".cmt", count: 1))
      # Enter on an empty field leaves nothing behind.
      |> click(css("#stop_comment"))
      |> send_keys([:enter])
      |> assert_has(css(".cmt", count: 1))
      |> fill_in(css("#stop_comment"), with: "I can call tomorrow morning")
      |> send_keys([:enter])
      # Appended after Tom's, signed by whoever is typing, in their own colour - and the field
      # is empty again for the next one.
      |> assert_has(css(".cmt", count: 2))
      |> assert_text(css(".cmt", at: 1), "NORA VALE")
      |> assert_text(css(".cmt", at: 1), "I can call tomorrow morning")

    session
    |> find(css(".cmt", at: 1))
    |> assert_has(css("i.y"))

    assert draft(session) == ""

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
    create_stop(trip, date: ~D[2026-03-30], name: "Fushimi Inari")

    session =
      session
      |> sign_in(trip)
      |> click(css(".stop", text: "Ryokan"))
      |> fill_in(css("#stop_comment"), with: "Onsen booked, dinner is not")
      |> click(css(".stop", text: "Fushimi Inari"))
      |> assert_text(css(".ed-title"), "Fushimi Inari")

    # The half-written remark was Ryokan's. The panel keeps its state from one stop to the
    # next, so the draft has to know which stop it was for.
    assert draft(session) == ""
  end

  feature "deleting a stop removes its remarks too", %{session: session, stop: stop, trip: trip} do
    create_comment(create_user("Tom Reyes", "tom@offgrid.test"), stop, "Onsen booked.")

    session
    |> sign_in(trip)
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

    Dates.clock(at, offset)
  end

  defp draft(session) do
    session
    |> find(css("#stop_comment"))
    |> Element.value()
  end
end
