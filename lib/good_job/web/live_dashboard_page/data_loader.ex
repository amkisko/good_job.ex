defmodule GoodJob.Web.LiveDashboardPage.DataLoader do
  @moduledoc """
  Data loading helpers for LiveDashboard page.
  """

  import Phoenix.Component
  alias GoodJob.{Job, Web.DataLoader}

  @doc """
  Loads data for a specific view.
  """
  def load_data_for_view(socket, :overview, _job_id, _params) do
    assign(socket, stats: DataLoader.load_stats(), chart_data: DataLoader.load_chart_data())
  end

  def load_data_for_view(socket, :cron, _job_id, _params) do
    assign(socket, cron_entries: DataLoader.load_cron_entries())
  end

  def load_data_for_view(socket, :pauses, _job_id, _params) do
    assign(socket, pauses: DataLoader.load_pauses())
  end

  def load_data_for_view(socket, :batches, _job_id, params) do
    page = socket.assigns[:current_page] || parse_page(params)
    per_page = socket.assigns.per_page

    {batches, total_count} = DataLoader.load_batches(page: page, per_page: per_page)

    assign(socket, batches: batches, total_count: total_count, current_page: page)
  end

  def load_data_for_view(socket, :processes, _job_id, _params) do
    assign(socket, processes: DataLoader.load_processes())
  end

  def load_data_for_view(socket, :jobs, _job_id, params) do
    page = socket.assigns[:current_page] || parse_page(params)
    per_page = socket.assigns.per_page

    {jobs, total_count} =
      DataLoader.load_jobs(
        page: page,
        per_page: per_page,
        state: socket.assigns.filter_state,
        queue: socket.assigns.filter_queue,
        job_class: socket.assigns.filter_job_class,
        search: socket.assigns.search_term
      )

    assign(socket, jobs: jobs, total_count: total_count, current_page: page)
  end

  def load_data_for_view(socket, :job_detail, job_id, _params) do
    job = if job_id, do: Job.find_by_id(job_id), else: nil
    executions = if job, do: DataLoader.load_executions(job.active_job_id), else: []

    assign(socket, job: job, executions: executions)
  end

  defp parse_page(%{"page" => page_str}) when is_binary(page_str) do
    case Integer.parse(page_str) do
      {page, _} -> max(1, page)
      _ -> 1
    end
  end

  defp parse_page(_), do: 1
end
