defmodule Offgrid.Features.PresenceTest do
  use Offgrid.FeatureCase, async: false

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
