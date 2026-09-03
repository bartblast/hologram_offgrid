defmodule Offgrid.Features.CommentsTest do
  use Offgrid.FeatureCase, async: false

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
