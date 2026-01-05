defmodule HabitTrackerWeb.Components.Dashboard do
  @moduledoc """
  Phlex component for the dashboard view.
  """
  use HabitTrackerWeb.Components.Base

  alias HabitTrackerWeb.Components.HabitCard

  defp render_template(assigns, _attrs, state) do
    original_assigns = Map.get(assigns, :_assigns, assigns)
    point_record = Map.get(original_assigns, :point_record)
    habits = Map.get(original_assigns, :habits, [])
    today = Map.get(original_assigns, :today)

    div(state, [class: "space-y-6"], fn state ->
      state
      |> render_stats_overview(point_record)
      |> render_habits_section(habits, today)
      |> render_job_monitoring_section()
    end)
  end

  defp render_stats_overview(state, point_record) do
    div(state, [class: "grid grid-cols-2 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4 lg:gap-6"], fn state ->
      state
      |> render_stat_card("🌟 Total Stars", "#{point_record.total_points}", "🌸", "linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)")
      |> render_stat_card("✨ Today", "#{point_record.points_today}", "🐱", "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)")
      |> render_stat_card("📅 This Week", "#{point_record.points_this_week}", "🌺", "linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%)")
      |> render_stat_card("📆 This Month", "#{point_record.points_this_month}", "🌷", "linear-gradient(135deg, #ff9a9e 0%, #fad0c4 100%)")
    end)
  end

  defp render_stat_card(state, label, value, emoji, gradient) do
    div(state, [
      class: "rounded-2xl sm:rounded-3xl shadow-lg sm:shadow-xl p-4 sm:p-5 lg:p-6 transition-smooth hover:scale-[1.02] sm:hover:scale-105 hover:shadow-2xl",
      style: "background: #{gradient}; border: 2px solid rgba(255,255,255,0.5);"
    ], fn state ->
      state
      |> div([class: "flex items-center justify-between mb-2"], fn state ->
        state
        |> span([class: "text-2xl sm:text-3xl"], emoji)
        |> div([class: "text-xs sm:text-sm font-bold text-right", style: "color: #5a3d5c;"], label)
      end)
      |> div([class: "text-2xl sm:text-3xl lg:text-4xl font-bold", style: "color: #2d1b2e; text-shadow: 2px 2px 4px rgba(255,255,255,0.5);"], value)
    end)
  end

  defp render_habits_section(state, habits, today) do
    div(state, [], fn state ->
      state
      |> div([class: "flex flex-col sm:flex-row items-start sm:items-center gap-2 sm:gap-3 mb-4 sm:mb-6"], fn state ->
        state
        |> span([class: "text-2xl sm:text-3xl lg:text-4xl"], "🌻")
        |> h2([class: "text-xl sm:text-2xl lg:text-3xl font-bold flex-1", style: "color: #5a3d5c; text-shadow: 2px 2px 4px rgba(255,255,255,0.8);"], fn state ->
          state
          |> span([class: "block sm:inline"], "My Garden Today")
          |> span([class: "hidden sm:inline"], " - ")
          |> span([class: "block sm:inline text-base sm:text-xl lg:text-2xl"], Calendar.strftime(today, "%B %d, %Y"))
        end)
        |> span([class: "text-2xl sm:text-3xl lg:text-4xl"], "🐱")
      end)
      |> div([class: "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-5 lg:gap-6"], fn state ->
        Enum.reduce(habits, state, fn habit_data, acc_state ->
          # Render HabitCard component
          card_html = HabitCard.render(%{
            habit: habit_data.habit,
            task: habit_data.task,
            streak: habit_data.streak,
            job_id: habit_data.job_id
          })

          # For now, we'll need to embed the HTML directly
          # In a full Phlex implementation, we'd use a component helper
          Phlex.SGML.append_raw(acc_state, Phlex.SGML.SafeValue.new(card_html))
        end)
      end)
    end)
  end

  defp render_job_monitoring_section(state) do
    div(state, [class: "mt-6 sm:mt-8"], fn state ->
      div(state, [
        class: "rounded-2xl sm:rounded-3xl shadow-lg sm:shadow-xl p-4 sm:p-6 transition-smooth hover:scale-[1.02] sm:hover:scale-105",
        style: "background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%); border: 2px solid rgba(255,255,255,0.5);"
      ], fn state ->
        state
        |> div([class: "flex items-center gap-2 mb-2 sm:mb-3"], fn state ->
          state
          |> span([class: "text-xl sm:text-2xl"], "⚙️")
          |> h3([class: "text-lg sm:text-xl font-bold", style: "color: #5a3d5c;"], "Magic Helper Jobs")
        end)
        |> p([class: "text-xs sm:text-sm mb-3 sm:mb-4", style: "color: #5a3d5c;"], "See what our helper cats are doing behind the scenes! 🌸")
        |> a([
          href: "/dashboard/good_job",
          class: "inline-flex items-center gap-2 px-4 sm:px-6 py-2 sm:py-3 rounded-full font-semibold text-sm sm:text-base transition-smooth button-press touch-target shadow-lg",
          style: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%); color: white; border: 2px solid rgba(255,255,255,0.5); min-height: 44px;"
        ], fn state ->
          state
          |> span([], "🐱")
          |> span([], "View Helper Dashboard")
        end)
      end)
    end)
  end
end
