defmodule MonorepoExampleWeb.Components.Jobs do
  @moduledoc """
  Phlex component for the jobs monitoring view.
  """
  use MonorepoExampleWeb.Components.Base

  alias GoodJob.Job

  defp render_template(assigns, _attrs, state) do
    original_assigns = Map.get(assigns, :_assigns, assigns)
    jobs = Map.get(original_assigns, :jobs, [])
    stats = Map.get(original_assigns, :stats, %{})
    csrf_token = Map.get(original_assigns, :csrf_token, "")

    div(state, [
      class: "space-y-6",
      style: "display: flex; flex-direction: column; gap: 1.5rem;"
    ], fn state ->
      state
      |> render_header()
      |> render_stats(stats)
      |> render_enqueue_section(csrf_token)
      |> render_jobs_table(jobs)
      |> render_footer()
    end)
  end

  defp render_header(state) do
    div(state, [
      class: "text-center text-white mb-6 sm:mb-8",
      style: "text-align: center; color: white; margin-bottom: 1.5rem;"
    ], fn state ->
      state
      |> h1([
        class: "text-2xl sm:text-3xl lg:text-4xl font-bold mb-2",
        style: "font-size: 1.5rem; font-weight: 700; margin-bottom: 0.5rem; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); color: white;"
      ], "🚀 Monorepo Example - Elixir Side")
      |> p([
        class: "text-base sm:text-lg opacity-90",
        style: "font-size: 1rem; opacity: 0.9; color: white; margin: 0;"
      ], "GoodJob Interactive Dashboard")
    end)
  end

  defp render_stats(state, stats) do
    div(state, [
      class: "grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4 mb-6",
      style: "display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem; margin-bottom: 1.5rem;"
    ], fn state ->
      state
      |> render_stat_card("Queued", Map.get(stats, :queued, 0))
      |> render_stat_card("Running", Map.get(stats, :running, 0))
      |> render_stat_card("Succeeded", Map.get(stats, :succeeded, 0))
      |> render_stat_card("Discarded", Map.get(stats, :discarded, 0))
      |> render_stat_card("Scheduled", Map.get(stats, :scheduled, 0))
    end)
  end

  defp render_stat_card(state, label, value) do
    div(state, [
      class: "bg-white rounded-xl p-4 sm:p-5 text-center shadow-md transition-transform hover:scale-105",
      style: "background: white; border-radius: 0.75rem; padding: 1rem; text-align: center; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); transition: transform 0.2s ease;"
    ], fn state ->
      state
      |> div([
        class: "text-xs sm:text-sm text-gray-700 mb-2 uppercase tracking-wide font-medium",
        style: "font-size: 0.75rem; color: #374151; margin-bottom: 0.5rem; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 500;"
      ], label)
      |> div([
        class: "text-2xl sm:text-3xl font-bold",
        style: "font-size: 1.5rem; font-weight: 700; color: #667eea;"
      ], to_string(value))
    end)
  end

  defp render_enqueue_section(state, csrf_token) do
    div(state, [
      class: "bg-white rounded-xl p-4 sm:p-6 mb-6 shadow-md",
      style: "background: white; border-radius: 0.75rem; padding: 1rem; margin-bottom: 1.5rem; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);"
    ], fn state ->
      state
      |> h2([
        class: "text-xl font-bold mb-4",
        style: "font-size: 1.25rem; font-weight: 700; color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; margin-bottom: 1rem; text-align: center;"
      ], "Enqueue Jobs")
      |> div([
        class: "flex gap-2 sm:gap-4 flex-wrap justify-center",
        style: "display: flex; gap: 0.5rem; flex-wrap: wrap; justify-content: center;"
      ], fn state ->
        state
        |> render_enqueue_form("elixir", csrf_token, "Enqueue Elixir Job", "background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);")
        |> render_enqueue_form("ruby", csrf_token, "Enqueue Ruby Job", "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);")
      end)
    end)
  end

  defp render_enqueue_form(state, job_type, csrf_token, button_text, button_style) do
    form(state, [
      action: "/jobs/enqueue",
      method: "post",
      style: "display: inline;"
    ], fn state ->
      state
      |> input([
        type: "hidden",
        name: "_csrf_token",
        value: csrf_token
      ])
      |> input([
        type: "hidden",
        name: "job_type",
        value: job_type
      ])
      |> button([
        type: "submit",
        class: "px-4 sm:px-6 py-2 sm:py-3 rounded-lg font-semibold text-white text-sm sm:text-base transition-transform hover:scale-105 shadow-lg cursor-pointer",
        style: "#{button_style} border: none; padding: 0.5rem 1rem; border-radius: 0.5rem; font-weight: 600; color: white; font-size: 0.875rem; cursor: pointer; box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05); transition: transform 0.1s ease;"
      ], button_text)
    end)
  end

  defp render_jobs_table(state, jobs) do
    div(state, [
      class: "bg-white rounded-xl p-4 sm:p-6 shadow-md overflow-hidden",
      style: "background: white; border-radius: 0.75rem; padding: 1rem; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); overflow: hidden;"
    ], fn state ->
      state
      |> h2([
        class: "text-xl font-bold mb-4",
        style: "font-size: 1.25rem; font-weight: 700; color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; margin-bottom: 1rem; text-align: center;"
      ], "Recent Jobs")
      |> render_if(Enum.any?(jobs), fn state ->
        div(state, [
          class: "overflow-x-auto",
          style: "overflow-x: auto;"
        ], fn state ->
          render_table(jobs).(state)
        end)
      end)
      |> render_if(!Enum.any?(jobs), fn state ->
        render_empty_state().(state)
      end)
    end)
  end

  defp render_if(state, condition, _fun) when condition in [nil, false], do: state
  defp render_if(state, _condition, fun), do: fun.(state)

  defp render_table(jobs) do
    fn state ->
      table(state, [
        class: "w-full border-collapse mt-4 min-w-full",
        style: "width: 100%; border-collapse: collapse; margin-top: 1rem; min-width: 100%;"
      ], fn state ->
        state
        |> thead(fn state ->
          tr(state, [
            class: "bg-gray-50",
            style: "background-color: #f9fafb;"
          ], fn state ->
            state
            |> th([
              class: "px-2 sm:px-4 py-3 text-left font-semibold text-gray-700 border-b-2 border-gray-200 whitespace-nowrap",
              style: "padding: 0.5rem 0.75rem; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb; white-space: nowrap;"
            ], "ID")
            |> th([
              class: "px-2 sm:px-4 py-3 text-left font-semibold text-gray-700 border-b-2 border-gray-200",
              style: "padding: 0.5rem 0.75rem; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb;"
            ], "Job Class")
            |> th([
              class: "px-2 sm:px-4 py-3 text-left font-semibold text-gray-700 border-b-2 border-gray-200",
              style: "padding: 0.5rem 0.75rem; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb;"
            ], "Queue")
            |> th([
              class: "px-2 sm:px-4 py-3 text-left font-semibold text-gray-700 border-b-2 border-gray-200 whitespace-nowrap",
              style: "padding: 0.5rem 0.75rem; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb; white-space: nowrap;"
            ], "Status")
            |> th([
              class: "px-2 sm:px-4 py-3 text-left font-semibold text-gray-700 border-b-2 border-gray-200 whitespace-nowrap",
              style: "padding: 0.5rem 0.75rem; text-align: left; font-weight: 600; color: #374151; border-bottom: 2px solid #e5e7eb; white-space: nowrap;"
            ], "Created At")
          end)
        end)
        |> tbody(fn state ->
          Enum.reduce(jobs, state, fn job, acc_state ->
            render_job_row(acc_state, job)
          end)
        end)
      end)
    end
  end

  defp render_job_row(state, job) do
    status = Job.calculate_state(job)
    job_id_short = job.id |> to_string() |> String.slice(0..7) |> Kernel.<>("...")
    # Fallback to serialized_params["job_class"] if job_class column is nil (consistent with Ruby dashboard)
    job_class_display = job.job_class ||
      (case job.serialized_params do
        %{"job_class" => class} when is_binary(class) -> class
        _ -> "N/A"
      end)

    tr(state, [
      class: "border-b border-gray-200 hover:bg-gray-50",
      style: "border-bottom: 1px solid #e5e7eb;"
    ], fn state ->
      state
      |> td([
        class: "px-2 sm:px-4 py-3 text-gray-900 whitespace-nowrap text-sm",
        style: "padding: 0.5rem 0.75rem; color: #111827; white-space: nowrap; font-size: 0.875rem;"
      ], job_id_short)
      |> td([
        class: "px-2 sm:px-4 py-3 text-gray-900",
        style: "padding: 0.5rem 0.75rem; color: #111827;"
      ], job_class_display)
      |> td([
        class: "px-2 sm:px-4 py-3 text-gray-900 text-sm",
        style: "padding: 0.5rem 0.75rem; color: #111827; font-size: 0.875rem;"
      ], job.queue_name || "default")
      |> td([
        class: "px-2 sm:px-4 py-3 whitespace-nowrap",
        style: "padding: 0.5rem 0.75rem; white-space: nowrap;"
      ], fn state ->
        span(state, [
          class: "inline-block px-2 sm:px-3 py-1 rounded-full text-xs font-semibold uppercase",
          style: "#{status_badge_style(status)} display: inline-block; padding: 0.25rem 0.5rem; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase;"
        ], String.capitalize(to_string(status)))
      end)
      |> td([
        class: "px-2 sm:px-4 py-3 text-gray-900 text-xs sm:text-sm whitespace-nowrap",
        style: "padding: 0.5rem 0.75rem; color: #111827; font-size: 0.75rem; white-space: nowrap;"
      ], DateTime.to_string(job.inserted_at))
    end)
  end

  defp render_empty_state do
    fn state ->
      p(state, [class: "text-gray-700"], "No jobs found. Enqueue a job to get started!")
    end
  end

  defp render_footer(state) do
    div(state, [
      class: "text-center text-white mt-8 opacity-80",
      style: "text-align: center; color: white; margin-top: 2rem; opacity: 0.8;"
    ], fn state ->
      p(state, [style: "margin: 0; color: white;"], fn state ->
        state
        |> span([], "Auto-refreshing every 5 seconds | ")
        |> a([href: "http://localhost:3000", class: "underline", style: "color: white; text-decoration: underline;"], "Rails Interface")
        |> span([], " | ")
        |> a([href: "/dashboard", class: "underline", style: "color: white; text-decoration: underline;"], "Phoenix LiveDashboard")
      end)
    end)
  end

  defp status_badge_style(:queued), do: "background: #e3f2fd; color: #1976d2;"
  defp status_badge_style(:running), do: "background: #fff3e0; color: #f57c00;"
  defp status_badge_style(:succeeded), do: "background: #e8f5e9; color: #388e3c;"
  defp status_badge_style(:discarded), do: "background: #ffebee; color: #d32f2f;"
  defp status_badge_style(:scheduled), do: "background: #f3e5f5; color: #7b1fa2;"
  defp status_badge_style(_), do: "background: #f5f5f5; color: #666;"
end
