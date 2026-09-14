defmodule Offgrid.Features.PingTest do
  use Offgrid.FeatureCase, async: false

  alias Hologram.DB
  alias Offgrid.Entities.Stop

  setup do
    reset_data()

    [trip: create_trip()]
  end

  # The one thing on this screen that is not a row: a ping is a gesture, so nothing stores it
  # and it leaves nothing behind.
  @sessions 2
  feature "points at a place on everyone else's map, and fades", %{
    sessions: [one, two],
    trip: trip
  } do
    one = sign_in(one, trip)
    two = sign_in(two, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    # Tom's arrival has been answered, so his page is on the channel before anybody pings it -
    # a ping sent while he is still joining reaches nobody, by design.
    assert_text(one, css(".faces"), "TR")

    # Unarmed, so a click on the map is a ping rather than a stop.
    one
    |> click(css("#canvas"))
    |> assert_has(css(".ping"))

    # It arrives on the other screen without anybody asking for it.
    assert_has(two, css(".ping"))

    # Nothing was written, and nothing is left after it fades.
    await_pending_writes(one, 0)
    assert DB.read(Stop) == []

    refute_has(one, css(".ping"))
    refute_has(two, css(".ping"))
  end
end
