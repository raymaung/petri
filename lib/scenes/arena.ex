defmodule Processor.Scene.Arena do
  use Scenic.Scene

  alias Scenic.Graph

  import Scenic.Primitives

  alias Processor.Component.Nav
  alias Processor.Component.ArenaUI
  alias Processor.Turtle
  alias Processor.Process

  @animate_ms 16

  @graph Graph.build(font: :roboto, font_size: 24)

  def init(_, opts) do
    viewport = opts[:viewport]

    graph =
      @graph
      |> Nav.add_to_graph(__MODULE__)
      |> ArenaUI.add_to_graph(__MODULE__)
      |> add_food(food_coords())
      |> push_graph()

    # start a very simple animation timer
    {:ok, _} = :timer.send_interval(@animate_ms, :animate)

    state = %{
      viewport: viewport,
      graph: graph,
      count: 0,
      food_x: 0,
      food_y: 0
    }

    new_state =
      state
      |> hatch_n(1)
      |> move_food

    {:ok, new_state}
  end

  def handle_info(:animate, state) do
    state
    |> update
    |> draw

    {:noreply, state}
  end

  def filter_event({:click, :btn_one}, _, state) do
    {:stop, hatch_n(state, 1)}
  end

  def filter_event({:click, :btn_ten}, _, state) do
    {:stop, hatch_n(state, 10)}
  end

  def filter_event({:click, :move_food}, _, state) do
    {:stop, move_food(state)}
  end

  def update(state) do
    turtles
    |> Enum.each(&Turtle.update(&1, state))

    state
  end

  def draw(state) do
    graph =
      turtles
      |> Enum.reduce(state.graph, &Turtle.draw(&1, &2))
      |> push_graph

    %{
      state
      | graph: graph
    }
  end

  def hatch(state) do
    {:ok, process} = DynamicSupervisor.start_child(TurtleSupervisor, {Turtle, state.count})

    new_state = %{
      state
      | graph: Turtle.add_to_graph(process, state.graph),
        count: state.count + 1
    }

    draw(new_state)
  end

  def hatch_n(state, count) do
    1..count
    |> Enum.reduce(state, fn _i, s ->
      hatch(s)
    end)
  end

  def turtles do
    TurtleSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn t ->
      {_, pid, _, _} = t
      pid
    end)
  end

  def add_food(graph, %{food_x: x, food_y: y}) do
    graph
    |> circle(10, id: :food, t: {x, y}, fill: {:color, :green})
  end

  def food_coords do
    %{
      food_x: Enum.random(100..700),
      food_y: Enum.random(100..700)
    }
  end

  def move_food(state) do
    coords = food_coords

    g =
      state.graph
      |> Graph.modify(
        :food,
        &update_opts(&1,
          translate: {coords.food_x, coords.food_y}
        )
      )

    %{
      state
      | graph: g,
        food_x: coords.food_x,
        food_y: coords.food_y
    }
  end
end
