defmodule Offgrid.Features.InkTest do
  use Offgrid.FeatureCase, async: false

  alias Wallaby.Element

  setup do
    truncate_trip_data()

    [trip: create_trip()]
  end

  feature "draws a stroke that follows the pointer, once the pen is armed",
          %{session: session, trip: trip} do
    session = sign_in_as_member(session, trip)

    # Unarmed the layer takes no pointer at all, so a drag over the map leaves no ink.
    session
    |> drag([{200, 150}, {260, 190}])
    |> refute_has(css(".ink-paper polyline", visible: :any))

    session
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
    |> drag([{200, 150}, {240, 170}, {280, 210}, {320, 200}])
    # The stroke stays on screen after the pointer lifts - it is drawn and nowhere else.
    |> assert_has(css(".ink-paper polyline", visible: :any))

    # One point per event, in the order the pointer went, and none of it sent anywhere.
    points = stroke_points(session)
    assert length(points) == 4
    assert await_pending_writes(session, 0)

    # Left to right, so the points went in the order they were made rather than reversed.
    [{first_x, _}, {_, _}, {_, _}, {last_x, _}] = points
    assert first_x < last_x

    # Putting the pen away discards it - G6 is what makes a stroke last.
    session
    |> send_keys([:escape])
    |> refute_has(css(".pen.on"))
    |> refute_has(css(".ink-paper polyline", visible: :any))
  end

  feature "the map can only be waiting for one thing", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
    |> click(css(".addb"))
    |> assert_has(css(".addb.on"))
    |> refute_has(css(".pen.on"))
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
    |> refute_has(css(".addb.on"))
  end

  # A press, a run of moves and a release over the ink layer, at offsets from its top left.
  defp drag(session, points) do
    [{first_x, first_y} | rest] = points
    {last_x, last_y} = List.last(points)

    moves =
      Enum.map_join(rest, "\n", fn {x, y} ->
        "layer.dispatchEvent(new PointerEvent('pointermove', at(#{x}, #{y})));"
      end)

    execute_script(session, """
    const layer = document.querySelector('.ink');
    const box = layer.getBoundingClientRect();
    const at = (x, y) => ({bubbles: true, clientX: box.left + x, clientY: box.top + y});

    layer.dispatchEvent(new PointerEvent('pointerdown', at(#{first_x}, #{first_y})));
    #{moves}
    layer.dispatchEvent(new PointerEvent('pointerup', at(#{last_x}, #{last_y})));
    """)

    session
  end

  defp stroke_points(session) do
    session
    |> find(css(".ink-paper polyline", visible: :any))
    |> Element.attr("points")
    |> String.split(" ", trim: true)
    |> Enum.map(fn pair ->
      [x, y] = String.split(pair, ",")

      {String.to_float(x), String.to_float(y)}
    end)
  end
end
