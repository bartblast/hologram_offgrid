# Offgrid

A collaborative trip planner, and the demo application for [Hologram](https://hologram.page) -
an Elixir framework that compiles your application to JavaScript and runs it in the browser.

Plan a trip with other people: stops with a day and a time, pins and a route on a map, remarks
on a stop, freehand ink, and who else is looking at it right now - their pointer on the map,
and a mark on the stop and the field they are editing. Everything but signing in works with
the network off and syncs when it comes back.

It runs inside a Phoenix endpoint, and every page, component and layout in it is Hologram's.

## Setup

You need Elixir 1.19 or later, Erlang/OTP 28 or later, and PostgreSQL running locally with a
`postgres` user whose password is `postgres`.

```bash
git clone https://github.com/bartblast/offgrid.git
cd offgrid
mix setup
createdb -U postgres offgrid_dev
mix seed
```

The seeds add the three maps a trip can be drawn on, four accounts, and three trips to look at -
one of them with stops, ink and a remark on it. Running them again is safe.

## Running it

```bash
mix holo
```

Then open [localhost:4000](http://localhost:4000) and sign in as `bart@offgrid.test` with the
password `japan-2026`. `mix holo` is `mix phx.server` with Hologram switched on - in dev and
test it stays off unless `HOLOGRAM_START=1` is set, which `mix holo` and `mix seed` both do.

The other three accounts - `emilia@`, `indiana@` and `lara@offgrid.test`, same password - are
on the Japan trip as well. Sign in as one of them in a second browser to see each other's
pointers, edits and ink live.

## Tests

```bash
mix test                  # unit tests
mix test --only feature   # feature tests, in a real browser
```

Feature tests drive Chrome through Wallaby, so they need Chrome and a matching ChromeDriver on
your PATH.
