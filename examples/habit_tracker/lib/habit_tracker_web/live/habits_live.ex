defmodule HabitTrackerWeb.HabitsLive do
  @moduledoc """
  LiveView for managing habits.
  """
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.Habit
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    habits = Repo.all(from h in Habit, order_by: [asc: h.category, asc: h.name])
    {:ok, assign(socket, habits: habits)}
  end

  @impl true
  def render(assigns) do
    Phlex.Phoenix.to_rendered(
      HabitTrackerWeb.Components.Habits.render(assigns)
    )
  end
end
