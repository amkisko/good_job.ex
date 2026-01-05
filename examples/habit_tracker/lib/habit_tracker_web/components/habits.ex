defmodule HabitTrackerWeb.Components.Habits do
  @moduledoc """
  Phlex component for the habits view.
  """
  use HabitTrackerWeb.Components.Base

  defp render_template(assigns, _attrs, state) do
    original_assigns = Map.get(assigns, :_assigns, assigns)
    habits = Map.get(original_assigns, :habits, [])

    div(state, [class: "space-y-6"], fn state ->
      state
      |> render_header()
      |> render_habits_table(habits)
    end)
  end

  defp render_header(state) do
    div(state, [class: "flex justify-between items-center"], fn state ->
      h2(state, [class: "text-2xl font-bold text-gray-800"], "All Habits")
    end)
  end

  defp render_habits_table(state, habits) do
    div(state, [class: "bg-white rounded-lg shadow overflow-hidden"], fn state ->
      table(state, [class: "min-w-full divide-y divide-gray-200"], fn state ->
        state
        |> render_table_header()
        |> render_table_body(habits)
      end)
    end)
  end

  defp render_table_header(state) do
    thead(state, [class: "bg-gray-50"], fn state ->
      tr(state, [], fn state ->
        state
        |> th([class: "px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"], "Name")
        |> th([class: "px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"], "Category")
        |> th([class: "px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"], "Points")
        |> th([class: "px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"], "Status")
      end)
    end)
  end

  defp render_table_body(state, habits) do
    tbody(state, [class: "bg-white divide-y divide-gray-200"], fn state ->
      Enum.reduce(habits, state, fn habit, acc_state ->
        render_habit_row(acc_state, habit)
      end)
    end)
  end

  defp render_habit_row(state, habit) do
    tr(state, [], fn state ->
      state
      |> td([class: "px-6 py-4 whitespace-nowrap"], fn state ->
        state
        |> div([class: "text-sm font-medium text-gray-900"], habit.name)
        |> render_if(habit.description, fn state ->
          div(state, [class: "text-sm text-gray-500"], habit.description)
        end)
      end)
      |> td([class: "px-6 py-4 whitespace-nowrap"], fn state ->
        span(state, [class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-blue-100 text-blue-800"], habit.category)
      end)
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm text-gray-900"], "#{habit.points_per_completion}")
      |> td([class: "px-6 py-4 whitespace-nowrap"], fn state ->
        if habit.enabled do
          span(state, [class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800"], "Enabled")
        else
          span(state, [class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-gray-100 text-gray-800"], "Disabled")
        end
      end)
    end)
  end

  defp render_if(state, condition, _fun) when condition in [nil, false], do: state
  defp render_if(state, _condition, fun), do: fun.(state)
end
