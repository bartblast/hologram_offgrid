# Offgrid

A collaborative trip planner, and the demo application for [Hologram](https://hologram.page) -
an Elixir framework that compiles your application to JavaScript and runs it in the browser.

Plan a trip with other people: stops with a day and a time, pins and a route on a map, remarks
on a stop, freehand ink, and who else is looking at it right now - their pointer on the map,
and a mark on the stop and the field they are editing. Everything but signing in works with
the network off and syncs when it comes back.

It runs inside a Phoenix endpoint, and every page, component and layout in it is Hologram's.

## Status

Offgrid tracks Hologram's unreleased development: `mix.exs` pins the dependency to a commit
rather than a Hex version.

Hologram's local-first data layer, which keeps the browser's database in sync with the server,
is still being worked on, so expect small changes to how the app reads and writes data. Not
everything here is how a Hologram app will look once that work lands, either. Presence (who is
here, their pointers and what they are editing) is built by hand from realtime broadcasts, and
the forms keep each field in page state themselves - both will get abstractions of their own in
Hologram soon.

## Requirements

- Elixir 1.19 or later and Erlang/OTP 28.1 or later
- Node.js, for the formatting and linting tools `mix setup` installs
- PostgreSQL 15 or later, running locally with a `postgres` user whose password is `postgres`

`.tool-versions` pins the exact Elixir, Erlang and Node.js versions CI uses.

## Setup

```bash
git clone https://github.com/bartblast/hologram_offgrid.git
cd hologram_offgrid
mix setup
createdb -U postgres offgrid_dev
mix seed
```

The seeds add the three maps a trip can be drawn on, four accounts, and three trips to look at -
one of them with stops, ink and a remark on it. Running them again is safe: anything already
there is left alone, including a trip you have since changed. To start over:

```bash
dropdb -U postgres offgrid_dev && createdb -U postgres offgrid_dev && mix seed
```

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
mix test                  # everything that does not need a browser
mix test --only feature   # feature tests, in a real browser, plus the tests that need the database
```

Feature tests drive Chrome through Wallaby, so they need Chrome and a matching ChromeDriver on
your PATH. They create and reset their own `offgrid_test` database.

## Checks and formatting

```bash
mix check   # compiler, formatters, Credo, Dialyzer, Sobelow, audits, ESLint, migrations and `mix test`
mix f       # formats the Elixir, CSS, JavaScript, JSON and YAML
```

With [lefthook](https://github.com/evilmartians/lefthook) installed, `lefthook install` adds a
pre-commit hook that checks the formatting.

## Production

Offgrid has no release configuration of its own. To run it with `MIX_ENV=prod`, set:

- `DATABASE_URL` - the database, for example `postgres://USER:PASS@HOST/offgrid`
- `SECRET_KEY_BASE` - generate one with `mix phx.gen.secret`
- `PHX_HOST` - the public host name
- `PORT` - optional, `4000` by default
- `POOL_SIZE` - optional, `10` by default

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix phx.server
```

`mix assets.deploy` writes the digested copy of the stylesheet that gives it a cache-busting URL.
The schema is brought up to date from `priv/hologram/migrations` when the app boots, so the
database only needs to exist. Public URLs are built as `https` on port 443, so put TLS in front
of the app. In a release, set `PHX_SERVER=true` to start the endpoint.

## License

Apache License 2.0 - see [LICENSE](LICENSE).
