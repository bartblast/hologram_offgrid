defmodule Offgrid.Features.PresenceTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.Auth

  setup do
    reset_data()

    [trip: create_trip()]
  end

  @sessions 2
  feature "shows who else is on the trip, whoever arrived first",
          %{sessions: [one, two], trip: trip} do
    one = sign_in(one, trip)

    # Alone, the pill carries only your own face.
    one
    |> assert_text(css(".faces"), "NV")
    |> assert_has(css(".face", count: 1))

    two = sign_in(two, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    # The arrival tells the room, and the room answers - so each sees the other without
    # either of them asking, and neither is listed twice.
    one
    |> assert_text(css(".faces"), "TR")
    |> assert_has(css(".face", count: 2))

    two
    |> assert_text(css(".faces"), "NV")
    |> assert_has(css(".face", count: 2))

    # Coloured by the cast: you are always yours, and the first other member is violet - so
    # each of them is violet on the other's screen, whoever arrived first.
    one
    |> assert_has(css(".face.y", text: "NV"))
    |> assert_has(css(".face.a", text: "TR"))

    two
    |> assert_has(css(".face.y", text: "TR"))
    |> assert_has(css(".face.a", text: "NV"))
  end

  @sessions 2
  feature "marks who is here in the members list", %{sessions: [one, two], trip: trip} do
    one = sign_in(one, trip)
    two = sign_in(two, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    # On the trip, never opened it today.
    anna = create_user("Anna Kim", "anna@offgrid.test")
    :ok = Auth.grant_role(anna, trip, :member)

    assert_text(one, css(".faces"), "TR")

    # Nora and Tom carry their colours, Anna the hollow "not here" dot - three rows, and the
    # dot says which of them is looking at the trip right now.
    one
    |> click(css(".facepile"))
    |> assert_has(css(".mrow", count: 3))
    |> assert_has(css(".mrow i.y", count: 1))
    |> assert_has(css(".mrow i.a", count: 1))
    |> assert_has(css(".mrow i.off", count: 1))

    assert_text(two, css(".faces"), "NV")
  end

  # The trip's live channel is the one door the policy does not guard - a stranger's rows are
  # empty by the trip's own rules, but a broadcast is not a row. So the page checks at the door.
  @sessions 3
  feature "tells a stranger nothing", %{sessions: [stranger, nora, tom], trip: trip} do
    # First in, so that anything the stranger's page might say to an arrival, it has the chance
    # to say.
    stranger =
      sign_in(stranger, trip, role: nil, name: "Mira Vale", email: "stranger@offgrid.test")

    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    # The round between the two members is complete, so whatever the stranger was going to
    # answer has long since been answered.
    assert_text(nora, css(".faces"), "TR")

    # Herself and Tom. Not the stranger, who was never let onto the channel to answer her.
    assert_has(nora, css(".face", count: 2))
    assert_has(tom, css(".face", count: 2))
    # And the stranger learns nothing of either arrival - only their own face.
    assert_has(stranger, css(".face", count: 1))
  end

  # Nothing here is a row: a pointer's place travels as a broadcast, is drawn on the other
  # screens, and is gone again once it stops moving.
  @sessions 2
  feature "shows where the other person is pointing, and lets it fade",
          %{sessions: [nora, tom], trip: trip} do
    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    # Both on the channel: each has seen the other's face.
    assert_text(nora, css(".faces"), "TR")
    assert_text(tom, css(".faces"), "NV")

    # Nora's pointer crosses her map.
    move_pointer(nora, [{300, 200}, {320, 210}, {340, 220}])

    # Tom sees her, by her letters and in her colour - the first other member is violet.
    tom
    |> assert_has(css(".cursor"))
    |> assert_text(css(".cursor"), "NV")
    |> assert_has(css(".cursor.a"))

    # She sees no cursor of her own, looked for only once her position has reached Tom.
    refute_has(nora, css(".cursor"))

    # And once she stops, the cursor fades on its own. This waits while it is still there, so
    # it is the fade being asserted rather than an absence that was never a presence.
    refute_has(tom, css(".cursor"))
  end

  # What somebody else has open travels the same way as their pointer, and shows twice: a
  # ring on the stop in the itinerary, and a tag beside the field they are in.
  @sessions 2
  feature "marks the stop and the field somebody else is editing",
          %{sessions: [nora, tom], trip: trip} do
    create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    assert_text(nora, css(".faces"), "TR")
    assert_text(tom, css(".faces"), "NV")

    # Nora opens the stop and lands in its name.
    nora
    |> click(css(".stop", text: "Ryokan"))
    |> click(css("#stop_name"))
    # Her own screen carries no mark of her own.
    |> refute_has(css(".sel"))
    |> refute_has(css(".tag"))

    # Tom sees the ring on the row, in her colour, before he has opened anything.
    tom
    |> assert_has(css(".stop .sel"))
    |> assert_text(css(".stop .sel"), "NV")
    |> assert_has(css(".stop .sel.a"))
    # Opening the same stop, he sees which field she is in.
    |> click(css(".stop", text: "Ryokan"))
    # One query rather than find-then-read-text: the label re-renders when the tag lands on it,
    # so an element found first can go stale before it is read.
    |> assert_has(css("label", text: "Name NV"))
    |> assert_has(css("label .tag", count: 1))
    |> assert_has(css(".inp.busy", count: 1))

    # She moves to the description; the tag moves with her.
    click(nora, css("#stop_description"))

    tom
    |> assert_has(css("label", text: "Description NV"))
    |> assert_has(css("label .tag", count: 1))

    # She closes the stop; both marks go.
    send_keys(nora, [:escape])

    tom
    |> refute_has(css(".sel"))
    |> refute_has(css(".tag"))
  end

  @sessions 2
  feature "tells a newcomer what is already open", %{sessions: [nora, tom], trip: trip} do
    create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    nora = sign_in(nora, trip)

    nora
    |> click(css(".stop", text: "Ryokan"))
    |> click(css("#stop_name"))

    # Tom arrives afterwards. Nora's answer to his arrival carries what she has open, so the
    # ring is on his screen at once - nobody had to move.
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    tom
    |> assert_text(css(".faces"), "NV")
    |> assert_has(css(".stop .sel"))
    |> assert_text(css(".stop .sel"), "NV")
  end

  # Nothing tells this browser that the other one has gone: the framework notices the stream
  # die and says nothing an app can hear. So the arrangement is inverted - everyone keeps
  # saying they are here, and going quiet is what means gone.
  @sessions 2
  feature "lets somebody go when their browser stops answering",
          %{sessions: [nora, tom], trip: trip} do
    create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    # Tom is here, and on a stop, so Nora carries both his face and his ring.
    tom
    |> click(css(".stop", text: "Ryokan"))
    |> click(css("#stop_name"))

    nora
    |> assert_text(css(".faces"), "TR")
    |> assert_has(css(".stop .sel"))

    # His browser goes. Nothing is sent, nothing is announced - it simply stops answering.
    Wallaby.end_session(tom)

    # And after three turns of silence Nora lets him go, face and mark together. Her own face
    # stays, which is what says this is a departure rather than the pill emptying.
    nora
    |> refute_has(css(".stop .sel"))
    |> refute_has(css(".face", text: "TR"))
    |> assert_text(css(".faces"), "NV")
  end

  # Pointer moves over the map's click surface, fifty milliseconds apart - no faster than the
  # page's pointer throttle.
  defp move_pointer(session, points) do
    dispatch_pointer(session, Enum.map(points, &{:move, "#canvas", &1}), delay: 50)
  end
end
