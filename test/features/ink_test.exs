defmodule Offgrid.Features.InkTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Entities.Sketch
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
    |> refute_has(css(".ink-paper path", visible: :any))

    session
    |> click(css(".pen"))
    |> assert_has(css(".pen.on"))
    # Still pressed: the live stroke follows the pointer and nothing has been written.
    |> press([{200, 150}, {240, 170}, {280, 210}, {320, 200}])
    |> assert_has(css(".ink-paper path", visible: :any))

    # The line starts where the pointer went down and ends where it is now, left to right - and
    # bends between, rather than running straight from one sample to the next: a curve needs a
    # neighbour on each side, so four points make two of them and the ends are joined straight.
    # One names its control and the rest continue from it, which is why both letters count.
    d = stroke_path(session)
    [{first_x, _first_y} | _rest] = places = stroke_places(d)
    {last_x, _last_y} = List.last(places)
    assert first_x < last_x
    assert length(String.split(d, ["Q", "T"])) - 1 == 2

    assert DB.read(Sketch) == []

    # Lifting the pointer is what writes it. The live layer hands over to the saved one.
    session = release(session, {320, 200})

    assert await_pending_writes(session, 0)
           |> refute_has(css(".ink-paper path", visible: :any))
           |> assert_has(css(".ink-line", count: 1, visible: :any))

    [sketch] = Sketch |> include(:author) |> DB.read()
    assert sketch.author.email == "member@offgrid.test"
    assert sketch.color == "#ff2d55"
    # Stored as the line itself, in the map's own coordinates: a move, two curves and a close.
    # Longitude rises eastward and latitude is written negative, so the drawing grows downward
    # the way a screen does.
    assert String.starts_with?(sketch.points, "M")
    assert length(String.split(sketch.points, ["Q", "T"])) - 1 == 2
    assert String.contains?(sketch.points, ",-")

    # And it is still there on a reload, drawn from the row rather than from the screen.
    session
    |> visit(TripPage, id: trip.id)
    |> assert_has(css(".ink-line", count: 1, visible: :any))
  end

  feature "rubs out a line with the pen out, and only one it may", %{session: session, trip: trip} do
    other = create_user("Tom Reyes", "tom@offgrid.test")

    theirs =
      %{
        author_id: other.id,
        color: "#30b0c7",
        # A line in the map's own coordinates, the way one is stored: longitude across,
        # latitude down.
        points: "M135.7,-35.1 L135.9,-35.2",
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
      # Arming + and putting it away again is no reason to forget the colour: the pen comes
      # back out in the colour it was put away with.
      |> click(css(".addb"))
      |> assert_has(css(".addb.on"))
      |> click(css(".addb"))
      |> click(css(".pen"))
      |> assert_has(css(".cdot.on", count: 1))
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
    |> refute_has(css(".ink-saved path", visible: :any))

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

  defp stroke_path(session) do
    session
    |> find(css(".ink-paper path", visible: :any))
    |> Element.attr("d")
  end

  # Every place the path names, whatever command carries it - enough to say where the line
  # begins and ends without this test knowing how a curve is spelled.
  defp stroke_places(d) do
    ~r/(-?[\d.]+),(-?[\d.]+)/
    |> Regex.scan(d)
    |> Enum.map(fn [_pair, x, y] -> {String.to_float(x), String.to_float(y)} end)
  end
end
