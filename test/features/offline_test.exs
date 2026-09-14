defmodule Offgrid.Features.OfflineTest do
  use Offgrid.FeatureCase, async: false
  use Hologram.DB

  alias Hologram.DB
  alias Offgrid.Entities.Comment
  alias Offgrid.Entities.Stop
  alias Offgrid.Entities.Trip
  alias Offgrid.Pages.NewTripPage
  alias Offgrid.Pages.TripPage
  alias Wallaby.HTTPClient

  setup do
    reset_data()

    [trip: create_trip()]
  end

  @sessions 2
  feature "edits a stop with no network, and the edits reach everyone once it is back",
          %{sessions: [nora, tom], trip: trip} do
    stop = create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    nora
    |> click(css(".stop", text: "Ryokan"))
    |> assert_text(css(".ed-title"), "Ryokan")
    |> go_offline()
    # Each edit is a write to the browser's own database, so each shows before anything travels.
    |> append_to_name(" Hoshi")
    |> assert_text(css(".stop.open .stop-name"), "Ryokan Hoshi")
    |> click(css(".times button", text: "18:00"))
    |> assert_text(css(".stop.open .stop-summary"), "18:00")
    |> fill_in(css("#stop_comment"), with: "Dinner is at seven")
    |> send_keys([:enter])
    |> assert_text(css(".cmt"), "Dinner is at seven")
    |> go_online()

    # Tom asked for nothing: the rows reach his screen once Nora's queue has shipped.
    tom
    |> assert_text(css(".stop .stop-name"), "Ryokan Hoshi")
    |> assert_text(css(".stop .stop-summary"), "18:00")
    |> click(css(".stop", text: "Ryokan Hoshi"))
    |> assert_text(css(".cmt"), "Dinner is at seven")

    await_pending_writes(nora, 0)

    saved = read_stop(stop.id)

    assert saved.name == "Ryokan Hoshi"
    assert Time.compare(saved.time, ~T[18:00:00]) == :eq

    assert [%Comment{body: "Dinner is at seven"}] =
             Comment
             |> filter(stop_id: stop.id)
             |> DB.read()
  end

  # Two people on the same stop, each with no network, each changing a different field. The
  # server merges per column, so neither edit costs the other.
  @sessions 2
  feature "merges edits two browsers made apart once both are back",
          %{sessions: [nora, tom], trip: trip} do
    stop = create_stop(trip, date: ~D[2026-03-29], name: "Ryokan")

    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    go_offline(nora)
    go_offline(tom)

    nora
    |> click(css(".stop", text: "Ryokan"))
    |> append_to_name(" Hoshi")
    |> assert_text(css(".stop.open .stop-name"), "Ryokan Hoshi")

    tom
    |> click(css(".stop", text: "Ryokan"))
    |> fill_in(css("#stop_description"), with: "Onsen booked")
    |> assert_text(css(".stop.open .stop-summary"), "Onsen booked")

    go_online(nora)
    go_online(tom)

    # Each screen ends up with both edits, whichever landed first.
    nora
    |> assert_text(css(".stop .stop-summary"), "Onsen booked")
    |> assert_text(css(".stop .stop-name"), "Ryokan Hoshi")

    tom
    |> assert_text(css(".stop .stop-name"), "Ryokan Hoshi")
    |> assert_text(css(".stop .stop-summary"), "Onsen booked")

    await_pending_writes(nora, 0)
    await_pending_writes(tom, 0)

    saved = read_stop(stop.id)

    assert saved.name == "Ryokan Hoshi"
    assert saved.description == "Onsen booked"
  end

  # A ping is a command, and a command that cannot reach the server raises. The page asks the
  # browser whether it has a network before sending one.
  @sessions 2
  feature "pings with no network without sending it or failing",
          %{sessions: [nora, tom], trip: trip} do
    nora = sign_in(nora, trip)
    tom = sign_in(tom, trip, name: "Tom Reyes", email: "tom@offgrid.test")

    assert_text(tom, css(".faces"), "NV")

    go_offline(nora)

    # Nora's heartbeat stops reaching Tom, so he lets her go - nothing from her gets through.
    refute_has(tom, css(".face", text: "NV"))

    nora
    |> click(css("#canvas"))
    |> assert_has(css(".ping"))

    refute_has(tom, css(".ping"))

    nora
    # Faded, which leaves a failed send the whole life of the ping to put its overlay up.
    |> refute_has(css(".ping"))
    |> refute_has(css("#hologram-uncaught-error-overlay"))
    |> go_online()

    # Back on the channel: her heartbeat reaches Tom again, and so does her next ping.
    assert_text(tom, css(".faces"), "NV")

    nora
    |> click(css("#canvas"))
    |> assert_has(css(".ping"))

    assert_has(tom, css(".ping"))
  end

  # The server refuses a channel for a trip it has not heard of, which is what a trip made offline
  # is until its batch lands. The page asks again after a pause.
  @sessions 2
  feature "joins a trip made offline once the server has it",
          %{sessions: [nora, tom], trip: trip} do
    create_user("Tom Reyes", "tom@offgrid.test")

    nora
    |> sign_in(trip)
    |> visit(NewTripPage)
    |> fill_in(css("#trip_name"), with: "Alps, hut to hut")
    |> fill_date("starts_on", "2026-08-02")
    |> fill_date("ends_on", "2026-08-09")
    |> click(css(".thumbs .thumb", at: 0))
    |> fill_in(css("#member_email"), with: "tom@offgrid.test")
    |> send_keys([:enter])
    |> assert_text(css(".chips"), "tom@offgrid.test")
    |> record_command_answers()
    |> hold_mutation_requests()
    |> click(button("Create trip"))
    |> assert_text(css(".lp-title"), "Alps, hut to hut")
    # The first join has been refused, so what follows can only succeed through the retry.
    |> await_command_answer("join_refused")
    |> release_mutations()
    |> await_pending_writes(0)

    alps =
      Trip
      |> filter(name: "Alps, hut to hut")
      |> one()
      |> DB.read()

    tom
    |> log_in("tom@offgrid.test")
    |> visit(TripPage, id: alps.id)
    |> assert_text(css(".lp-title"), "Alps, hut to hut")

    # Each sees the other, which takes both pages on the trip's channel.
    assert_text(nora, css(".faces"), "TR")
    assert_text(tom, css(".faces"), "NV")
  end

  # Typed at the end of what is there rather than through `fill_in/3`, whose clear fires no input
  # event - the editor re-renders the stored name back into the field before the typing starts.
  defp append_to_name(session, text) do
    session
    |> click(css("#stop_name"))
    |> send_keys([:end, text])
  end

  # Polls what `record_command_answers/1` kept until one of the answers names the action.
  defp await_command_answer(session, action, attempts_left \\ 200)

  defp await_command_answer(_session, action, 0) do
    raise Wallaby.ExpectationNotMetError, "No command was answered with #{action}"
  end

  defp await_command_answer(session, action, attempts_left) do
    script =
      "return (globalThis.__commandAnswers || []).some((text) => text.includes(arguments[0]));"

    execute_script(session, script, [action], fn
      true ->
        :ok

      _answered ->
        Process.sleep(50)
        await_command_answer(session, action, attempts_left - 1)
    end)
  end

  defp go_offline(session), do: emulate_network(session, true)

  defp go_online(session), do: emulate_network(session, false)

  # Chrome's own network emulation, so the browser reports being offline the way a real one does
  # and every request fails, the stream included.
  defp emulate_network(session, offline?) do
    params = %{downloadThroughput: -1, latency: 0, offline: offline?, uploadThroughput: -1}

    {:ok, _result} = cdp(session, "Network.enable", %{})
    {:ok, _result} = cdp(session, "Network.emulateNetworkConditions", params)

    session
  end

  defp cdp(session, command, params) do
    HTTPClient.request(:post, "#{session.url}/chromium/send_command_and_get_result", %{
      cmd: command,
      params: params
    })
  end

  defp read_stop(id) do
    Stop
    |> filter(id: id)
    |> one()
    |> DB.read()
  end

  # Keeps the text of every command answer the page receives. A command's answer is not on screen,
  # and the refusal is the only thing that says the retry is what joined.
  defp record_command_answers(session) do
    execute_script(session, """
    const real = globalThis.fetch.bind(globalThis);

    globalThis.__commandAnswers = [];

    globalThis.fetch = async (url, opts) => {
      const response = await real(url, opts);

      if (url === "/hologram/command") {
        response.clone().text().then((text) => globalThis.__commandAnswers.push(text));
      }

      return response;
    };
    """)
  end
end
