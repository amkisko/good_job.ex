defmodule HabitTrackerWeb.Components.Analytics do
  @moduledoc """
  Phlex component for the analytics view.
  """
  use HabitTrackerWeb.Components.Base

  defp render_template(assigns, _attrs, state) do
    original_assigns = Map.get(assigns, :_assigns, assigns)
    analytics = Map.get(original_assigns, :analytics, [])

    div(state, [class: "space-y-6"], fn state ->
      state
      |> render_header()
      |> render_analytics_table(analytics)
    end)
  end

  defp render_header(state) do
    div(state, [class: "flex justify-between items-center mb-6"], fn state ->
      state
      |> div([class: "flex items-center gap-3"], fn state ->
        state
        |> span([class: "text-4xl"], "📊")
        |> h2([class: "text-3xl font-bold", style: "color: #5a3d5c; text-shadow: 2px 2px 4px rgba(255,255,255,0.8);"], "My Garden Stats 🌸")
      end)
      |> render_buttons()
    end)
  end

  defp render_buttons(state) do
    div(state, [class: "flex space-x-3"], fn state ->
      state
      |> render_button("daily", "📅 Daily", "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)")
      |> render_button("weekly", "📆 Weekly", "linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%)")
      |> render_button("monthly", "🗓️ Monthly", "linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)")
    end)
  end

  defp render_button(state, period, label, gradient) do
    button(state, [
      class: "px-5 py-3 rounded-2xl font-bold text-sm transition-all hover:scale-110 shadow-lg",
      style: "background: #{gradient}; color: white; border: 2px solid rgba(255,255,255,0.5);",
      phx_click: "calculate_analytics",
      phx_value_period: period
    ], label)
  end

  defp render_analytics_table(state, analytics) do
    div(state, [
      class: "rounded-3xl shadow-xl overflow-hidden",
      style: "background: linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.7) 100%); border: 3px solid rgba(255,255,255,0.6);"
    ], fn state ->
      table(state, [class: "min-w-full"], fn state ->
        state
        |> render_table_header()
        |> render_table_body(analytics)
      end)
    end)
  end

  defp render_table_header(state) do
    thead(state, [style: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%);"], fn state ->
      tr(state, [], fn state ->
        state
        |> th([class: "px-6 py-4 text-left text-sm font-bold", style: "color: #2d1b2e;"], "📅 Period")
        |> th([class: "px-6 py-4 text-left text-sm font-bold", style: "color: #2d1b2e;"], "📆 Date Range")
        |> th([class: "px-6 py-4 text-left text-sm font-bold", style: "color: #2d1b2e;"], "⭐ Completion")
        |> th([class: "px-6 py-4 text-left text-sm font-bold", style: "color: #2d1b2e;"], "✅ Done")
        |> th([class: "px-6 py-4 text-left text-sm font-bold", style: "color: #2d1b2e;"], "🌟 Stars")
        |> th([class: "px-6 py-4 text-left text-sm font-bold", style: "color: #2d1b2e;"], "🐱 When")
      end)
    end)
  end

  defp render_table_body(state, analytics) do
    tbody(state, [class: "divide-y", style: "border-color: rgba(255,255,255,0.3);"], fn state ->
      Enum.reduce(analytics, state, fn analytic, acc_state ->
        render_analytic_row(acc_state, analytic)
      end)
    end)
  end

  defp render_analytic_row(state, analytic) do
    tr(state, [class: "hover:bg-pink-50 transition-colors"], fn state ->
      state
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm font-bold", style: "color: #5a3d5c;"], String.capitalize(analytic.period))
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm", style: "color: #5a3d5c;"], "#{Calendar.strftime(analytic.period_start, "%Y-%m-%d")} - #{Calendar.strftime(analytic.period_end, "%Y-%m-%d")}")
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm font-semibold", style: "color: #2d1b2e;"], format_completion_rate(analytic.completion_rate))
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm font-semibold", style: "color: #2d1b2e;"], "#{analytic.total_completions || 0}")
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm font-semibold", style: "color: #2d1b2e;"], "🌟 #{analytic.total_points || 0}")
      |> td([class: "px-6 py-4 whitespace-nowrap text-sm", style: "color: #5a3d5c;"], format_calculated_at(analytic.inserted_at))
    end)
  end

  defp format_completion_rate(nil), do: "N/A"
  defp format_completion_rate(rate), do: "#{Float.round(rate * 100, 1)}%"

  defp format_calculated_at(nil), do: "N/A"
  defp format_calculated_at(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_string()
    |> String.slice(0, 16)
  end
  defp format_calculated_at(datetime), do: to_string(datetime)
end
