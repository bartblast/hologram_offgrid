defmodule Offgrid.Features.SocialTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.Auth
  alias Hologram.DB
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.User
  alias Offgrid.Pages.LogInPage
  alias Offgrid.Pages.TripPage
  alias Offgrid.Pages.TripsPage

  @password "hakone-2026"

  setup do
    truncate_trip_data()

    trip = create_trip()

    stop =
      %{
        date: ~D[2026-03-29],
        lat: 35.0116,
        lng: 135.7681,
        name: "Fushimi Inari",
        trip_id: trip.id
      }
      |> Stop.new()
      |> DB.create!()

    [stop: stop, trip: trip]
  end

  # Everything two people can say to each other on this screen, in one sitting. Each half is
  # tested on its own elsewhere; what this watches is that none of it needs asking for.
  @sessions 2
  feature "carries a remark, a line, a ping and an arrival between two browsers",
          %{sessions: [nora, tom], trip: trip} do
    nora = sign_in_as_member(nora, trip)
    tom = sign_in_as(tom, trip, "Tom Reyes", "tom@offgrid.test")

    # Arriving is itself the first thing that crosses.
    assert_text(nora, css(".faces"), "TR")
    assert_text(tom, css(".faces"), "NV")

    # A remark, written on one screen and read on the other.
    nora
    |> click(css(".stop", text: "Fushimi Inari"))
    |> fill_in(css(".editor .inp", at: 2), with: "Before eight, the crowds come at nine")
    |> send_keys([:enter])

    tom
    |> click(css(".stop", text: "Fushimi Inari"))
    |> assert_text(css(".editor"), "Before eight, the crowds come at nine")
    |> assert_text(css(".editor"), "NORA VALE")

    # A line, drawn on one screen and inked on the other, in the colour it was drawn with.
    tom
    |> click(css(".pen"))
    |> click(css(".cdot", at: 2))
    |> draw([{220, 160}, {260, 200}, {300, 240}])

    assert await_pending_writes(tom, 0)
    assert_has(nora, css(".ink-line", count: 1, visible: :any))

    stroke = nora |> find(css(".ink-line", visible: :any)) |> Wallaby.Element.attr("stroke")
    assert stroke == "#30b0c7"

    # A ping, which is the one thing here that leaves nothing behind.
    tom
    |> click(css(".pen"))
    |> click(css("#canvas"))

    assert_has(nora, css(".ping"))
    refute_has(nora, css(".ping"))
  end

  # A whole stroke over the ink layer, at offsets from its top left.
  defp draw(session, points) do
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

  defp sign_in_as(session, trip, name, email) do
    user =
      %{email: email, name: name, password_hash: Bcrypt.hash_pwd_salt(@password)}
      |> User.new()
      |> DB.create!()

    :ok = Auth.grant_role(user, trip, :member)

    session
    |> visit(LogInPage)
    |> fill_in(css(".card .inp", at: 0), with: email)
    |> fill_in(css(".card .inp", at: 1), with: @password)
    |> click(button("Log in"))
    |> assert_page(TripsPage)
    |> visit(TripPage, id: trip.id)
  end
end
