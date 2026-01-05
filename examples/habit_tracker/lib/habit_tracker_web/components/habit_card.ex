defmodule HabitTrackerWeb.Components.HabitCard do
  @moduledoc """
  Phlex component for rendering a habit card with task completion.
  """
  use HabitTrackerWeb.Components.Base

  defp render_template(assigns, _attrs, state) do
    # Access original assigns
    original_assigns = Map.get(assigns, :_assigns, assigns)
    habit = Map.get(original_assigns, :habit)
    task = Map.get(original_assigns, :task)
    streak = Map.get(original_assigns, :streak)
    job_id = Map.get(original_assigns, :job_id)

    gradient = category_gradient(habit.category)
    emoji = category_emoji(habit.category)

    attrs = Phlex.StyleCapsule.add_capsule_attr([
      class: "rounded-2xl sm:rounded-3xl shadow-lg sm:shadow-xl p-4 sm:p-6 transition-smooth hover:scale-[1.02] sm:hover:scale-105 hover:shadow-2xl",
      style: "background: #{gradient}; border: 2px solid rgba(255,255,255,0.6);"
    ], __MODULE__)

    div(state, attrs, fn state ->
      state
      |> div([class: "flex flex-col sm:flex-row justify-between items-start gap-2 sm:gap-0 mb-3 sm:mb-4"], fn state ->
        state
        |> div([class: "flex items-center gap-2 flex-1 min-w-0"], fn state ->
          state
          |> span([class: "text-2xl sm:text-3xl flex-shrink-0"], emoji)
          |> div([class: "min-w-0 flex-1"], fn state ->
            state
            |> h3([class: "text-base sm:text-lg md:text-xl font-bold text-truncate", style: "color: #2d1b2e; text-shadow: 1px 1px 2px rgba(255,255,255,0.5);"], habit.name)
            |> render_if(habit.description, fn state ->
              span(state, [class: "text-xs sm:text-sm mt-1 block text-truncate-2", style: "color: #5a3d5c;"], habit.description)
            end)
          end)
        end)
        |> span([
          class: "px-2 sm:px-3 py-1 text-xs font-bold rounded-full shadow-md flex-shrink-0",
          style: "background: rgba(255,255,255,0.9); color: #5a3d5c;"
        ], habit.category)
      end)
      |> div([class: "space-y-2 sm:space-y-3"], fn state ->
        state
        |> div([class: "flex justify-between items-center p-2 sm:p-3 rounded-xl sm:rounded-2xl", style: "background: rgba(255,255,255,0.5);"], fn state ->
          state
          |> div([class: "flex items-center gap-1 sm:gap-2"], fn state ->
            state
            |> span([class: "text-lg sm:text-xl"], "⭐")
            |> span([class: "text-xs sm:text-sm font-semibold", style: "color: #5a3d5c;"], "Stars per task:")
          end)
          |> span([class: "text-base sm:text-lg font-bold", style: "color: #2d1b2e;"], "#{habit.points_per_completion}")
        end)
        |> render_if(streak, fn state ->
          div(state, [class: "flex justify-between items-center p-2 sm:p-3 rounded-xl sm:rounded-2xl", style: "background: rgba(255,255,255,0.5);"], fn state ->
            state
            |> div([class: "flex items-center gap-1 sm:gap-2"], fn state ->
              state
              |> span([class: "text-lg sm:text-xl"], "🔥")
              |> span([class: "text-xs sm:text-sm font-semibold", style: "color: #5a3d5c;"], "Streak:")
            end)
            |> span([class: "text-base sm:text-lg font-bold", style: "color: #2d1b2e;"], "#{streak.current_streak} days 🌸")
          end)
        end)
        |> render_if(task, fn state ->
          div(state, [class: "mt-3 sm:mt-4 pt-3 sm:pt-4", style: "border-top: 2px dashed rgba(255,255,255,0.6);"], fn state ->
            state
            |> div([class: "flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 sm:gap-0 mb-2 sm:mb-3"], fn state ->
              state
              |> div([class: "flex items-center gap-1 sm:gap-2"], fn state ->
                state
                |> span([class: "text-lg sm:text-xl"], "📋")
                |> span([class: "text-xs sm:text-sm font-bold", style: "color: #5a3d5c;"], "Today's Task")
              end)
              |> render_completion_status(task, habit)
            end)
            |> render_completion_button(task, habit, job_id)
            |> render_if(job_id, fn state ->
              div(state, [class: "mt-2 sm:mt-3 p-2 sm:p-3 rounded-xl sm:rounded-2xl", style: "background: rgba(255,255,255,0.6);", id: "job-status-container-#{task.id}"], fn state ->
                div(state, [
                  id: "job-status-#{task.id}",
                  "phx-hook": "JobStatusTracker",
                  "phx-update": "ignore",
                  "data-job-id": job_id,
                  "data-task-id": "#{task.id}"
                ], fn state ->
                  div(state, [class: "flex items-center gap-2"], fn state ->
                    state
                    |> span([class: "text-lg sm:text-xl"], "🐱")
                    |> div([class: "w-4 h-4 sm:w-5 sm:h-5 border-2 sm:border-3 border-pink-300 border-t-pink-600 rounded-full animate-spin"], fn state -> state end)
                    |> span([class: "text-xs sm:text-sm font-bold", style: "color: #5a3d5c;"], "Helper cat is working! 🌸")
                  end)
                end)
              end)
            end)
          end)
        end)
        |> render_if(!task, fn state ->
          div(state, [class: "mt-3 sm:mt-4 pt-3 sm:pt-4 p-3 sm:p-4 rounded-xl sm:rounded-2xl text-center", style: "background: rgba(255,255,255,0.5); border: 2px dashed rgba(255,255,255,0.6);"], fn state ->
            state
            |> span([class: "text-xl sm:text-2xl block mb-2"], "🌱")
            |> span([class: "text-xs sm:text-sm font-semibold block", style: "color: #5a3d5c;"], "No task for today - rest time! 🐱")
          end)
        end)
      end)
    end)
  end

  defp render_completion_status(state, task, habit) do
    max_completions = habit.max_completions || 1
    completion_count = task.completion_count || 0

    cond do
      completion_count >= max_completions ->
        # Limit reached
        span(state, [
          class: "px-2 sm:px-3 py-1 text-xs font-bold rounded-full shadow-md whitespace-nowrap",
          style: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%); color: #2d1b2e;"
        ], fn state ->
          state
          |> span([], "🎉")
          |> span([class: "hidden sm:inline"], " All Done! ")
          |> span([], "(#{completion_count}/#{max_completions})")
        end)

      completion_count > 0 ->
        # Partially completed
        span(state, [
          class: "px-2 sm:px-3 py-1 text-xs font-bold rounded-full shadow-md whitespace-nowrap",
          style: "background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%); color: #2d1b2e;"
        ], fn state ->
          state
          |> span([], "✅")
          |> span([], " #{completion_count}/#{max_completions}")
        end)

      true ->
        # Not started
        span(state, [
          class: "px-2 sm:px-3 py-1 text-xs font-bold rounded-full shadow-md whitespace-nowrap",
          style: "background: rgba(255,255,255,0.7); color: #5a3d5c;"
        ], fn state ->
          state
          |> span([], "⏳")
          |> span([], " Waiting")
        end)
    end
  end

  defp render_completion_button(state, task, habit, job_id) do
    max_completions = habit.max_completions || 1
    completion_count = task.completion_count || 0
    can_complete_more = completion_count < max_completions

    if can_complete_more && !job_id do
      div(state, [class: "mt-2 sm:mt-3 w-full"], fn state ->
        button_text = if completion_count > 0, do: "Complete Again! (#{completion_count + 1}/#{max_completions})", else: "Complete Task!"
        button_text_mobile = if completion_count > 0, do: "Again (#{completion_count + 1}/#{max_completions})", else: "Complete!"

        button(state, [
          class: "w-full px-4 sm:px-6 py-3 sm:py-4 rounded-xl sm:rounded-2xl font-bold text-sm sm:text-base md:text-lg transition-smooth button-press touch-target shadow-lg",
          style: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%); color: white; border: 2px solid rgba(255,255,255,0.5); min-height: 44px;",
          phx_click: "complete_task",
          phx_value_task_id: "#{task.id}"
        ], fn state ->
          state
          |> span([], "🐱")
          |> span([class: "hidden sm:inline"], " #{button_text}")
          |> span([class: "sm:hidden"], " #{button_text_mobile}")
          |> span([], " 🌸")
        end)
      end)
    else
      state
    end
  end

  defp render_if(state, condition, _fun) when condition in [nil, false], do: state
  defp render_if(state, _condition, fun), do: fun.(state)

  defp category_gradient("hygiene"), do: "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)"
  defp category_gradient("exercise"), do: "linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%)"
  defp category_gradient("sleep"), do: "linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)"
  defp category_gradient("chores"), do: "linear-gradient(135deg, #ffecd2 0%, #ffd89b 100%)"
  defp category_gradient(_), do: "linear-gradient(135deg, #fef3e2 0%, #ffe5f1 100%)"

  defp category_emoji("hygiene"), do: "🧼"
  defp category_emoji("exercise"), do: "🏃"
  defp category_emoji("sleep"), do: "😴"
  defp category_emoji("chores"), do: "🧹"
  defp category_emoji(_), do: "⭐"
end
