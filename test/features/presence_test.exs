defmodule Offgrid.Features.PresenceTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Offgrid.Entities.Stop

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  # Nothing here is a row: a pointer's place travels as a broadcast, is drawn on the other
  # screens, and is gone again once it stops moving.
  @sessions 2
  feature "shows where the other person is pointing, and lets it fade",
          %{sessions: [nora, tom], trip: trip} do
    nora = sign_in_as_member(nora, trip)
    tom = sign_in_as(tom, trip, "Tom Reyes", "tom@offgrid.test")

    # Both on the channel: each has seen the other's face.
    assert_text(nora, css(".faces"), "TR")
    assert_text(tom, css(".faces"), "NV")

    # Nora's pointer crosses her map. She sees no cursor of her own.
    nora
    |> move_pointer([{300, 200}, {320, 210}, {340, 220}])
    |> refute_has(css(".cursor"))

    # Tom sees her, by her letters and in her colour - the first other member is violet.
    tom
    |> assert_has(css(".cursor"))
    |> assert_text(css(".cursor"), "NV")
    |> assert_has(css(".cursor.a"))
    # And once she stops, the cursor fades on its own. This waits while it is still there, so
    # it is the fade being asserted rather than an absence that was never a presence.
    |> refute_has(css(".cursor"))
  end

  # What somebody else has open travels the same way as their pointer, and shows twice: a
  # ring on the stop in the itinerary, and a tag beside the field they are in.
  @sessions 2
  feature "marks the stop and the field somebody else is editing",
          %{sessions: [nora, tom], trip: trip} do
    %{date: ~D[2026-03-29], name: "Ryokan", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    nora = sign_in_as_member(nora, trip)
    tom = sign_in_as(tom, trip, "Tom Reyes", "tom@offgrid.test")

    assert_text(nora, css(".faces"), "TR")
    assert_text(tom, css(".faces"), "NV")

    # Nora opens the stop and lands in its name.
    nora
    |> click(css(".stop", text: "Ryokan"))
    # By name rather than by position: three inputs and an index is a fragile way to say which
    # field, and Wallaby picking the wrong one made this feature fail about two runs in five.
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
    # One query rather than find-then-read-text: the label is re-rendered the moment the tag
    # lands on it, so an element found first and read second goes stale about one run in three.
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
    %{date: ~D[2026-03-29], name: "Ryokan", trip_id: trip.id}
    |> Stop.new()
    |> DB.create!()

    nora = sign_in_as_member(nora, trip)

    nora
    |> click(css(".stop", text: "Ryokan"))
    |> click(css("#stop_name"))

    # Tom arrives afterwards. Nora's answer to his arrival carries what she has open, so the
    # ring is on his screen at once - nobody had to move.
    tom = sign_in_as(tom, trip, "Tom Reyes", "tom@offgrid.test")

    tom
    |> assert_text(css(".faces"), "NV")
    |> assert_has(css(".stop .sel"))
    |> assert_text(css(".stop .sel"), "NV")
  end

  # Pointer moves over the map's click surface, at offsets from its top left, fifty
  # milliseconds apart - slower than the throttle, so each one is sent.
  defp move_pointer(session, points) do
    moves =
      Enum.map_join(points, "\n", fn {x, y} ->
        "setTimeout(() => canvas.dispatchEvent(new PointerEvent('pointermove', at(#{x}, #{y}))), delay); delay += 50;"
      end)

    execute_script(session, """
    const canvas = document.getElementById('canvas');
    const box = canvas.getBoundingClientRect();
    const at = (x, y) => ({bubbles: true, clientX: box.left + x, clientY: box.top + y});
    let delay = 0;
    #{moves}
    """)

    session
  end
end
