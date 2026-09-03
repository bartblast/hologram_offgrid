# Offgrid

A collaborative trip planner, and the demo application for [Hologram](https://hologram.page) -
an Elixir framework that compiles your application to JavaScript and runs it in the browser.

Plan a trip with other people: stops with a day and a time, pins and a route on a map, remarks
on a stop, freehand ink, and who else is looking at it right now. Everything but signing in
works with the network off and syncs when it comes back.

It runs alongside a stock Phoenix application rather than replacing one - the endpoint, the
router and the layouts are Phoenix's, and every page is Hologram's.

## Setup

You need Elixir 1.19 or later, Erlang/OTP 27 or later, and PostgreSQL running locally.

```bash
git clone https://github.com/bartblast/offgrid.git
cd offgrid
mix setup
HOLOGRAM_START=1 mix run priv/seeds.exs
```

The seeds add the three maps a trip can be drawn on and one trip to look at.

## Running it

```bash
mix holo
```

Then open [localhost:4000](http://localhost:4000) and create an account. `mix holo` is
`mix phx.server` with Hologram switched on - in dev and test it stays off unless
`HOLOGRAM_START=1` is set, which is why the seeds command above sets it too.

The trip the seeds create belongs to nobody, so a new account will not see it. Make your own
from the trips screen.

## Tests

```bash
mix test                  # unit tests
mix test --only feature   # feature tests, in a real browser
```

Feature tests drive Chrome through Wallaby, so they need Chrome and a matching ChromeDriver on
your PATH.
