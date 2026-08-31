

# Offgrid

This repository contains a bare-bones skeleton application for the Hologram web framework, built on top of Phoenix. It provides a minimal starting point for:

- Experimenting with Hologram
- Reproducing issues for bug reports
- Learning the basics of Hologram development
- Creating new Hologram applications

## Getting Started

To start your Hologram application:

1. Clone this repository
   ```bash
   git clone https://github.com/bartblast/offgrid.git
   cd offgrid
   ```

2. Install dependencies
   ```bash
   mix setup
   ```

3. Start the Phoenix server
   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser to see the Hologram application running.

## File Organization

Hologram follows a convention of placing page and component files in the `app` directory. However, you can place your files in any directory that is compiled by the Elixir compiler, such as the `lib` directory.

## Database Configuration

To enable database functionality, uncomment the `Offgrid.Repo` line in `lib/offgrid/application.ex`:

```elixir
children = [
  OffgridWeb.Telemetry,
  Offgrid.Repo,  # Uncomment this line
  # ...
]
```

## Learn More

Visit the official Hologram website at [https://hologram.page](https://hologram.page) for comprehensive documentation and guides.

## License

This project is licensed under the same license as Hologram itself.
