defmodule HabitTrackerWeb.Components.Jobs do
  @moduledoc """
  Phlex component for the jobs monitoring view.
  """
  use HabitTrackerWeb.Components.Base

  defp render_template(assigns, _attrs, state) do
    original_assigns = Map.get(assigns, :_assigns, assigns)
    jobs = Map.get(original_assigns, :jobs, [])
    stats = Map.get(original_assigns, :stats, %{})
    filter_state = Map.get(original_assigns, :filter_state)
    filter_queue = Map.get(original_assigns, :filter_queue)

    div(state, [class: "space-y-4 sm:space-y-6"], fn state ->
      state
      |> div([class: "flex items-center gap-2 sm:gap-3 mb-4 sm:mb-6"], fn state ->
        state
        |> span([class: "text-2xl sm:text-3xl lg:text-4xl"], "⚙️")
        |> h2([class: "text-xl sm:text-2xl lg:text-3xl font-bold", style: "color: #5a3d5c; text-shadow: 2px 2px 4px rgba(255,255,255,0.8);"], "Helper Cats at Work 🐱")
      end)
      |> render_stats(stats)
      |> render_filters(filter_state, filter_queue)
      |> render_jobs_table(jobs)
    end)
  end

  defp render_filters(state, filter_state, filter_queue) do
    div(state, [
      class: "rounded-xl sm:rounded-2xl shadow-md p-3 sm:p-4",
      style: "background: linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.7) 100%); border: 2px solid rgba(255,255,255,0.6);"
    ], fn state ->
      form(state, [
        phx_change: "filter",
        phx_submit: "filter",
        class: "flex flex-col sm:flex-row gap-3 sm:gap-4 items-stretch sm:items-end"
      ], fn state ->
        state
        |> div([class: "flex-1 min-w-0"], fn state ->
          label(state, [class: "block text-xs sm:text-sm font-bold mb-1 sm:mb-2", style: "color: #5a3d5c;"], "Filter by Status")
          select(state, [
            name: "state",
            class: "w-full px-3 py-2 sm:py-2.5 rounded-lg border-2 border-pink-200 focus:border-pink-500 focus:outline-none touch-target",
            style: "background: white; color: #5a3d5c; min-height: 44px; font-size: 16px;"
          ], fn state ->
            state
            |> option([value: ""], "All Statuses")
            |> option([value: "queued", selected: filter_state == "queued"], "Queued")
            |> option([value: "running", selected: filter_state == "running"], "Running")
            |> option([value: "succeeded", selected: filter_state == "succeeded"], "Succeeded")
            |> option([value: "discarded", selected: filter_state == "discarded"], "Discarded")
            |> option([value: "scheduled", selected: filter_state == "scheduled"], "Scheduled")
          end)
        end)
        |> div([class: "flex-1 min-w-0"], fn state ->
          label(state, [class: "block text-xs sm:text-sm font-bold mb-1 sm:mb-2", style: "color: #5a3d5c;"], "Filter by Queue")
          input(state, [
            type: "text",
            name: "queue",
            value: filter_queue || "",
            placeholder: "Queue name",
            class: "w-full px-3 py-2 sm:py-2.5 rounded-lg border-2 border-pink-200 focus:border-pink-500 focus:outline-none touch-target",
            style: "background: white; color: #5a3d5c; min-height: 44px; font-size: 16px;"
          ])
        end)
        |> div([class: "flex-shrink-0"], fn state ->
          button(state, [
            type: "submit",
            class: "w-full sm:w-auto px-4 sm:px-6 py-2.5 sm:py-2 bg-gradient-to-r from-pink-400 to-purple-500 text-white rounded-lg hover:from-pink-500 hover:to-purple-600 transition-smooth button-press font-bold shadow-md touch-target text-sm sm:text-base",
            style: "min-height: 44px;"
          ], "🔍 Filter")
        end)
      end)
    end)
  end

  defp render_stats(state, stats) do
    div(state, [class: "grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3 sm:gap-4 lg:gap-6"], fn state ->
      state
      |> render_stat_card("⏳ Waiting", "#{stats.queued || 0}", "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)")
      |> render_stat_card("🏃 Running", "#{stats.running || 0}", "linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%)")
      |> render_stat_card("✅ Done!", "#{stats.succeeded || 0}", "linear-gradient(135deg, #a8edea 0%, #fed6e3 100%)")
      |> render_stat_card("😿 Oops", "#{stats.discarded || 0}", "linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%)")
      |> render_stat_card("📅 Scheduled", "#{stats.scheduled || 0}", "linear-gradient(135deg, #ffecd2 0%, #ffd89b 100%)")
    end)
  end

  defp render_stat_card(state, label, value, gradient) do
    div(state, [
      class: "rounded-2xl sm:rounded-3xl shadow-lg sm:shadow-xl p-3 sm:p-4 lg:p-6 transition-smooth hover:scale-[1.02] sm:hover:scale-105 hover:shadow-2xl",
      style: "background: #{gradient}; border: 2px solid rgba(255,255,255,0.5);"
    ], fn state ->
      state
      |> div([class: "text-xs sm:text-sm font-bold mb-1 sm:mb-2", style: "color: #5a3d5c;"], label)
      |> div([class: "text-2xl sm:text-3xl lg:text-4xl font-bold", style: "color: #2d1b2e; text-shadow: 2px 2px 4px rgba(255,255,255,0.5);"], value)
    end)
  end

  defp render_jobs_table(state, jobs) do
    div(state, [
      class: "rounded-xl sm:rounded-2xl lg:rounded-3xl shadow-lg sm:shadow-xl overflow-hidden",
      style: "background: linear-gradient(135deg, rgba(255,255,255,0.9) 0%, rgba(255,255,255,0.7) 100%); border: 2px solid rgba(255,255,255,0.6);"
    ], fn state ->
      div(state, [class: "table-responsive overflow-x-auto -webkit-overflow-scrolling: touch"], fn state ->
        table(state, [class: "min-w-full"], fn state ->
          state
          |> render_table_header()
          |> render_table_body(jobs)
        end)
      end)
    end)
  end

  defp render_table_header(state) do
    thead(state, [style: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%);"], fn state ->
      tr(state, [], fn state ->
        state
        |> th([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left text-xs sm:text-sm font-bold", style: "color: #2d1b2e;"], "🐱 Helper")
        |> th([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left text-xs sm:text-sm font-bold hidden sm:table-cell", style: "color: #2d1b2e;"], "📋 Queue")
        |> th([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left text-xs sm:text-sm font-bold", style: "color: #2d1b2e;"], "🌸 Status")
        |> th([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left text-xs sm:text-sm font-bold hidden lg:table-cell", style: "color: #2d1b2e;"], "⭐ Priority")
        |> th([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left text-xs sm:text-sm font-bold hidden md:table-cell", style: "color: #2d1b2e;"], "📅 When")
        |> th([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-left text-xs sm:text-sm font-bold", style: "color: #2d1b2e;"], "⚡ Actions")
      end)
    end)
  end

  defp render_table_body(state, jobs) do
    tbody(state, [class: "divide-y", style: "border-color: rgba(255,255,255,0.3);"], fn state ->
      Enum.reduce(jobs, state, fn job, acc_state ->
        render_job_row(acc_state, job)
      end)
    end)
  end

  defp render_job_row(state, job) do
    job_state = GoodJob.Job.calculate_state(job)
    state_str = to_string(job_state)
    can_retry = job_state == :discarded

    tr(state, [class: "hover:bg-pink-50 transition-colors"], fn state ->
      state
      |> td([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-xs sm:text-sm font-bold", style: "color: #5a3d5c;"], fn state ->
        span(state, [class: "block truncate max-w-[150px] sm:max-w-none"], job.job_class)
      end)
      |> td([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-xs sm:text-sm hidden sm:table-cell", style: "color: #5a3d5c;"], job.queue_name || "")
      |> td([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4"], fn state ->
        span(state, [
          class: "px-2 sm:px-3 py-1 inline-flex text-xs leading-5 font-bold rounded-full shadow-md whitespace-nowrap",
          style: state_badge_style(job_state)
        ], "#{state_emoji(job_state)} #{String.capitalize(state_str)}")
      end)
      |> td([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-xs sm:text-sm font-semibold hidden lg:table-cell", style: "color: #2d1b2e;"], "⭐ #{job.priority}")
      |> td([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4 text-xs sm:text-sm hidden md:table-cell", style: "color: #5a3d5c;"], Calendar.strftime(job.inserted_at, "%Y-%m-%d %H:%M:%S"))
      |> td([class: "px-3 sm:px-4 lg:px-6 py-3 sm:py-4"], fn state ->
        div(state, [class: "flex flex-col sm:flex-row gap-1 sm:gap-2"], fn state ->
          state = if can_retry do
            button(state, [
              phx_click: "retry_job",
              phx_value_job_id: job.id,
              class: "px-2 sm:px-3 py-1.5 sm:py-1 bg-gradient-to-r from-green-400 to-green-500 text-white text-xs rounded-lg hover:from-green-500 hover:to-green-600 transition-smooth button-press font-bold shadow-md touch-target",
              style: "min-height: 36px; min-width: 44px;",
              "data-confirm": "Are you sure you want to retry this job?"
            ], fn state ->
              span(state, [], "🔄 Retry")
            end)
          else
            state
          end

          button(state, [
            phx_click: "delete_job",
            phx_value_job_id: job.id,
            class: "px-2 sm:px-3 py-1.5 sm:py-1 bg-gradient-to-r from-red-400 to-red-500 text-white text-xs rounded-lg hover:from-red-500 hover:to-red-600 transition-smooth button-press font-bold shadow-md touch-target",
            style: "min-height: 36px; min-width: 44px;",
            "data-confirm": "Are you sure you want to delete this job? This action cannot be undone."
          ], fn state ->
            span(state, [], "🗑️ Delete")
          end)
        end)
      end)
    end)
  end

  defp state_badge_style(:queued), do: "background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%); color: #2d1b2e;"
  defp state_badge_style(:running), do: "background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%); color: #2d1b2e;"
  defp state_badge_style(:succeeded), do: "background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%); color: #2d1b2e;"
  defp state_badge_style(:discarded), do: "background: linear-gradient(135deg, #ff9a9e 0%, #fecfef 100%); color: #2d1b2e;"
  defp state_badge_style(:scheduled), do: "background: linear-gradient(135deg, #ffecd2 0%, #ffd89b 100%); color: #2d1b2e;"
  defp state_badge_style(_), do: "background: rgba(255,255,255,0.7); color: #5a3d5c;"

  defp state_emoji(:queued), do: "⏳"
  defp state_emoji(:running), do: "🏃"
  defp state_emoji(:succeeded), do: "✅"
  defp state_emoji(:discarded), do: "😿"
  defp state_emoji(:scheduled), do: "📅"
  defp state_emoji(_), do: "🌸"
end
