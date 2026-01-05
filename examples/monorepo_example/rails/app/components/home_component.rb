class HomeComponent < ApplicationComponent
  include StyleCapsule::Component

  def initialize(jobs:, stats:)
    @jobs = jobs
    @stats = stats
  end

  def view_template
    # Content only - LayoutComponent provides container, header, and footer
    # StyleCapsule automatically renders styles and wraps content
    div(class: "space-y-6", style: "display: flex; flex-direction: column; gap: 1.5rem;") do
      turbo_frame_tag "stats_frame", src: stats_path do
        # Initial content shown while loading
        render_stats
      end
      render_enqueue_section
      turbo_frame_tag "jobs_frame", src: jobs_path do
        # Initial content shown while loading
        render_jobs_table
      end
    end
  end

  private

  def render_stats
    div(class: "stats-grid") do
      render_stat_card("Queued", @stats[:queued])
      render_stat_card("Running", @stats[:running])
      render_stat_card("Succeeded", @stats[:finished] || @stats[:succeeded])
      render_stat_card("Discarded", @stats[:discarded])
      render_stat_card("Scheduled", @stats[:scheduled])
    end
  end

  def render_stat_card(label, value)
    div(class: "stat-card") do
      div(class: "label") { label }
      div(class: "value") { value.to_s }
    end
  end

  def render_enqueue_section
    div(class: "section") do
      h2 { "Enqueue Jobs" }
      div(class: "enqueue-buttons") do
        render_enqueue_form("elixir", "Enqueue Elixir Job", "btn-success")
        render_enqueue_form("example", "Enqueue Ruby Job", "btn-primary")
      end
    end
  end

  def render_enqueue_form(job_type, label, btn_class)
    form_tag(jobs_enqueue_path, method: :post, style: "display: inline;", data: { turbo_frame: "_top" }) do
      hidden_field_tag("job_type", job_type)
      submit_tag(label, class: "btn #{btn_class}")
    end
  end

  def render_enqueue_form_with_message(job_type, label, btn_class)
    form_tag(jobs_enqueue_path, method: :post, style: "display: inline;", data: { turbo_frame: "_top" }) do
      hidden_field_tag("job_type", job_type)
      hidden_field_tag("message", "Custom message from UI")
      submit_tag(label, class: "btn #{btn_class}")
    end
  end

  def render_jobs_table
    div(class: "section") do
      h2 { "Recent Jobs" }
      if @jobs && !@jobs.empty?
        div(class: "jobs-table-wrapper") do
          table(class: "jobs-table") do
          thead do
            tr do
              th { "ID" }
              th { "Job Class" }
              th { "Queue" }
              th { "Status" }
              th { "Created At" }
            end
          end
          tbody do
            @jobs.each do |job|
              tr do
                td { job.id.to_s[0..7] + "..." }
                td { job.job_class || job.serialized_params&.dig("job_class") || "N/A" }
                td { job.queue_name || "default" }
                td { render_status_badge(job.status) }
                td { job.created_at.strftime("%Y-%m-%d %H:%M:%S") }
              end
            end
          end
          end
        end
      else
        p(class: "text-gray-700") { "No jobs found. Enqueue a job to get started!" }
      end
    end
  end

  def render_status_badge(status)
    # Map "finished" to "succeeded" for consistency with Elixir side
    badge_class = case status.to_s
    when "finished"
      "badge-succeeded"
    else
      "badge-#{status}"
    end
    display_status = case status.to_s
    when "finished"
      "Succeeded"
    else
      status.to_s.capitalize
    end
    span(class: "badge #{badge_class}") { display_status }
  end

  def component_styles
    <<~CSS
      .space-y-6 > * + * {
        margin-top: 1.5rem;
      }
      .text-gray-700 {
        color: #374151;
      }
      .text-gray-900 {
        color: #111827;
      }
      .stats-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr); /* grid-cols-2 */
        gap: 1rem; /* gap-4 */
        margin-bottom: 1.5rem; /* mb-6 */
      }
      @media (min-width: 640px) {
        .stats-grid {
          grid-template-columns: repeat(3, 1fr); /* sm:grid-cols-3 */
        }
      }
      @media (min-width: 1024px) {
        .stats-grid {
          grid-template-columns: repeat(5, 1fr); /* lg:grid-cols-5 */
        }
      }
      .space-y-6 {
        display: flex;
        flex-direction: column;
        gap: 1.5rem;
      }
      .stat-card {
        background: white; /* bg-white */
        border-radius: 0.75rem; /* rounded-xl */
        padding: 1rem 1.25rem; /* p-4 sm:p-5 */
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); /* shadow-md */
        text-align: center;
        height: 100%;
        transition: transform 0.2s ease;
      }
      @media (min-width: 640px) {
        .stat-card {
          padding: 1.25rem; /* p-5 */
        }
      }
      .stat-card:hover {
        transform: scale(1.05); /* hover:scale-105 */
      }
      .stat-card .label {
        font-size: 0.75rem; /* text-xs */
        color: #374151; /* text-gray-700 */
        margin-bottom: 0.5rem; /* mb-2 */
        text-transform: uppercase;
        font-weight: 500; /* font-medium */
        letter-spacing: 0.05em; /* tracking-wide */
      }
      @media (min-width: 640px) {
        .stat-card .label {
          font-size: 0.875rem; /* text-sm */
        }
      }
      .stat-card .value {
        font-size: 1.5rem; /* text-2xl */
        font-weight: 700; /* font-bold */
        color: #667eea;
      }
      @media (min-width: 640px) {
        .stat-card .value {
          font-size: 1.875rem; /* text-3xl */
        }
      }
      .section {
        background: white; /* bg-white */
        border-radius: 0.75rem; /* rounded-xl */
        padding: 1rem 1.5rem; /* p-4 sm:p-6 */
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06); /* shadow-md */
        margin-bottom: 1.5rem; /* mb-6 - Add margin between sections */
        overflow: hidden; /* Prevent overflow */
      }
      @media (min-width: 640px) {
        .section {
          padding: 1.5rem; /* p-6 */
        }
      }
      .section h2 {
        font-size: 1.25rem; /* text-xl */
        font-weight: 700; /* font-bold */
        color: #333; /* Match Phoenix: color: #333 */
        margin-bottom: 1rem; /* mb-4 */
        padding-bottom: 0.625rem; /* padding-bottom: 10px */
        border-bottom: 2px solid #667eea;
        text-align: center;
      }
      .enqueue-buttons {
        display: flex;
        justify-content: center;
        gap: 0.5rem 1rem; /* gap-2 sm:gap-4 */
        flex-wrap: wrap;
      }
      .btn {
        padding: 0.5rem 1rem; /* px-4 py-2 */
        border-radius: 0.5rem; /* rounded-lg */
        border: none;
        color: white;
        font-weight: 600; /* font-semibold */
        font-size: 0.875rem; /* text-sm */
        line-height: 1.5;
        cursor: pointer;
        transition: transform 0.1s ease, box-shadow 0.2s ease;
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05); /* shadow-lg */
      }
      @media (min-width: 640px) {
        .btn {
          padding: 0.75rem 1.5rem; /* px-6 py-3 */
          font-size: 1rem; /* text-base */
        }
      }
      .btn:hover {
        transform: scale(1.05); /* hover:scale-105 */
        box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
      }
      .btn-primary {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      }
      .btn-success {
        background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%);
      }
      .btn-info {
        background: linear-gradient(135deg, #0dcaf0 0%, #0aa2c0 100%);
      }
      .jobs-table-wrapper {
        overflow-x: auto;
        margin-top: 1rem;
      }
      .jobs-table {
        width: 100%;
        min-width: 100%;
        border-collapse: collapse;
      }
      .jobs-table th, .jobs-table td {
        padding: 0.5rem 0.75rem; /* px-2 py-3 */
        text-align: left;
        white-space: nowrap;
      }
      @media (min-width: 640px) {
        .jobs-table th, .jobs-table td {
          padding: 0.75rem 1rem; /* px-4 py-3 */
        }
      }
      .jobs-table th:not(:first-child),
      .jobs-table td:not(:first-child) {
        white-space: normal;
      }
      .jobs-table th {
        background-color: #f9fafb; /* bg-gray-50 */
        font-weight: 600; /* font-semibold */
        color: #374151; /* text-gray-700 */
        border-bottom: 2px solid #e5e7eb; /* border-b-2 border-gray-200 */
      }
      .jobs-table td {
        color: #111827; /* text-gray-900 */
        border-bottom: 1px solid #e5e7eb; /* border-b border-gray-200 */
        font-size: 0.875rem; /* text-sm */
      }
      @media (min-width: 640px) {
        .jobs-table td {
          font-size: 1rem; /* text-base */
        }
      }
      .jobs-table tbody tr:hover {
        background-color: #f9fafb; /* hover:bg-gray-50 */
      }
      .badge {
        display: inline-block;
        padding: 0.25rem 0.75rem; /* px-3 py-1 */
        font-size: 0.75rem; /* text-xs */
        font-weight: 600; /* font-semibold */
        line-height: 1;
        text-align: center;
        white-space: nowrap;
        vertical-align: baseline;
        border-radius: 9999px; /* rounded-full */
        text-transform: uppercase;
      }
      .badge-queued {
        background-color: #e3f2fd; /* Match Phoenix exactly */
        color: #1976d2;
      }
      .badge-running {
        background-color: #fff3e0; /* Match Phoenix exactly */
        color: #f57c00;
      }
      .badge-succeeded {
        background-color: #e8f5e9; /* Match Phoenix exactly */
        color: #388e3c;
      }
      .badge-discarded {
        background-color: #ffebee; /* Match Phoenix exactly */
        color: #d32f2f;
      }
      .badge-scheduled {
        background-color: #f3e5f5; /* Match Phoenix exactly */
        color: #7b1fa2;
      }
      .badge-finished {
        background-color: #e8f5e9; /* Match succeeded */
        color: #388e3c;
      }
    CSS
  end
end

