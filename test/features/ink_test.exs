defmodule Offgrid.Features.InkTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Entities.Sketch
  alias Offgrid.Entities.User
  alias Offgrid.Pages.TripPage
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
    # Still pressed: the live stroke follows the pointer and nothing has been written.
    |> press([{200, 150}, {240, 170}, {280, 210}, {320, 200}])
    |> assert_has(css(".ink-paper polyline", visible: :any))

    # One point per event, in the order the pointer went, left to right.
    points = stroke_points(session)
    assert length(points) == 4
    [{first_x, _first_y}, _second, _third, {last_x, _last_y}] = points
    assert first_x < last_x

    assert DB.read(Sketch) == []

    # Lifting the pointer is what writes it. The live layer hands over to the saved one.
    session = release(session, {320, 200})

    assert await_pending_writes(session, 0)
           |> refute_has(css(".ink-paper polyline", visible: :any))
           |> assert_has(css(".ink-line", count: 1, visible: :any))

    [sketch] = Sketch |> include(:author) |> DB.read()
    assert sketch.author.email == "member@offgrid.test"
    assert sketch.color == "#ff2d55"
    assert length(String.split(sketch.points, " ", trim: true)) == 4

    # And it is still there on a reload, drawn from the row rather than from the screen.
    session
    |> visit(TripPage, id: trip.id)
    |> assert_has(css(".ink-line", count: 1, visible: :any))
  end

  feature "rubs out a line with the pen out, and only one it may", %{session: session, trip: trip} do
    other =
      %{email: "tom@offgrid.test", name: "Tom Reyes", password_hash: "x"}
      |> User.new()
      |> DB.create!()

    theirs =
      %{
        author_id: other.id,
        color: "#30b0c7",
        points: "35.1,135.7 35.2,135.9",
        trip_id: trip.id
      }
      |> Sketch.new()
      |> DB.create!()

    session =
      session
      |> sign_in_as_member(trip)
      |> click(css(".pen"))
      # Straight, so the middle of the line is the middle of its box - what a click aims at.
      |> drag([{200, 150}, {240, 190}, {280, 230}])

    assert await_pending_writes(session, 0)
           |> assert_has(css(".ink-line", count: 2, visible: :any))
           # A member may rub out their own line and not somebody else's, which the browser decides
           # for itself - so only one of the two takes the pointer at all.
           |> assert_has(css(".ink-hit", count: 1, visible: :any))
           |> click(css(".ink-hit"))
           |> assert_has(css(".ink-line", count: 1, visible: :any))

    assert await_pending_writes(session, 0)
    assert [remaining] = DB.read(Sketch)
    assert remaining.id == theirs.id
  end

  feature "draws in the colour that was picked", %{session: session, trip: trip} do
    session =
      session
      |> sign_in_as_member(trip)
      # The row of colours belongs to the pen, so it is not there until the pen is out.
      |> refute_has(css(".cpop"))
      |> click(css(".pen"))
      |> assert_has(css(".cdot", count: 5))
      |> assert_has(css(".cdot.on", count: 1))
      |> click(css(".cdot", at: 1))
      |> drag([{200, 150}, {240, 190}, {280, 230}])

    assert await_pending_writes(session, 0)

    [sketch] = DB.read(Sketch)
    assert sketch.color == "#af52de"

    # And the line on screen is drawn in it, read from the row rather than from the picker.
    stroke =
      session
      |> find(css(".ink-line", visible: :any))
      |> Element.attr("stroke")

    assert stroke == "#af52de"
  end

  feature "a tap is not a line", %{session: session, trip: trip} do
    session
    |> sign_in_as_member(trip)
    |> click(css(".pen"))
    |> drag([{200, 150}])
    |> refute_has(css(".ink-saved polyline", visible: :any))

    assert DB.read(Sketch) == []
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

  # A press and a run of moves over the ink layer, at offsets from its top left, with the
  # pointer still down at the end.
  defp press(session, [{first_x, first_y} | rest]) do
    moves =
      Enum.map_join(rest, "\n", fn {x, y} ->
        "layer.dispatchEvent(new PointerEvent('pointermove', at(#{x}, #{y})));"
      end)

    ink_script(session, """
    layer.dispatchEvent(new PointerEvent('pointerdown', at(#{first_x}, #{first_y})));
    #{moves}
    """)
  end

  defp release(session, {x, y}) do
    ink_script(session, "layer.dispatchEvent(new PointerEvent('pointerup', at(#{x}, #{y})));")
  end

  # A whole stroke, pressed and released.
  defp drag(session, points) do
    session
    |> press(points)
    |> release(List.last(points))
  end

  defp ink_script(session, body) do
    execute_script(session, """
    const layer = document.querySelector('.ink');
    const box = layer.getBoundingClientRect();
    const at = (x, y) => ({bubbles: true, clientX: box.left + x, clientY: box.top + y});

    #{body}
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
