defmodule Offgrid.Components.MapSurface do
  @moduledoc """
  The empty surface over the terrain that clicks and the pointer land on.

  A click goes to the page as a place in hundredths of the map, so nothing else needs the map's
  size. While the pointer moves, its position goes to everyone else on the trip.

  The surface is an empty element laid over the terrain rather than wrapped around it, because
  a click inside a child component does not reach a listener on the element around it.
  """

  use Hologram.Component

  import Offgrid.Classes

  alias Offgrid.Box
  alias Offgrid.TripChannel

  # How often this browser sends its pointer position while it moves. It has its own timer
  # because a throttled event dispatches on both edges of its window, which sent positions in
  # bursts. The timer stops when a tick finds nothing new to send.
  @cursor_ms 100

  prop :placing, :boolean
  prop :trip_id, :string

  def init(_props, component, _server) do
    component
    |> put_state(box: nil, pointer: nil, pointer_sent: nil, pointer_ticking: false)
    |> put_action(:measure)
  end

  # Measured on window resize: a window binding goes with the page, while a `$resize` on the
  # canvas fires once more as the element goes and lands on the next page.
  def template do
    ~HOLO"""
    <div
      id="canvas"
      class={classes(["canvas", placing: @placing])}
      $click="click"
      $pointer_move.throttle(50)="point"
    ></div>

    <window $resize="measure" />
    """
  end

  def action(:click, params, component) do
    case offset(component.state.box, params.event) do
      nil -> component
      place -> put_action(component, name: :map_clicked, target: "page", params: place)
    end
  end

  def action(:measure, _params, component) do
    put_state(component, :box, Box.rect("canvas"))
  end

  # Only remembered here. `:send_pointer` sends it on its own timer.
  #
  # Only the empty surface hears the pointer, so over a pin, the panel, the armed ink layer or
  # off the map, the last position fades on the other screens.
  def action(:point, params, component) do
    case offset(component.state.box, params.event) do
      nil ->
        component

      pointer ->
        moved = put_state(component, :pointer, pointer)

        if moved.state.pointer_ticking, do: moved, else: start_pointing(moved)
    end
  end

  # A tick with nothing new to send is the last one until the pointer moves again.
  def action(:send_pointer, _params, component) do
    state = component.state

    if state.pointer && state.pointer != state.pointer_sent do
      component
      |> put_state(:pointer_sent, state.pointer)
      |> TripChannel.tell(:cursor,
        trip_id: component.props.trip_id,
        x: state.pointer.x,
        y: state.pointer.y
      )
      |> put_action(name: :send_pointer, delay: @cursor_ms)
    else
      put_state(component, :pointer_ticking, false)
    end
  end

  def command(:cursor, params, server) do
    TripChannel.relay(
      server,
      params.trip_id,
      :cursor_moved,
      TripChannel.sender(server) ++ [x: params.x, y: params.y]
    )
  end

  # Where the event landed, in hundredths of the surface - or nil before it has been measured.
  defp offset(nil, _event), do: nil

  defp offset({_left, _top, width, height}, event) do
    %{x: event.offset_x / width * 100, y: event.offset_y / height * 100}
  end

  defp start_pointing(component) do
    component
    |> put_state(:pointer_ticking, true)
    |> put_action(name: :send_pointer, delay: @cursor_ms)
  end
end
