defmodule GoodJob.Web.DataLoader do
  @moduledoc """
  Data loading functions for GoodJob LiveDashboard.
  """

  alias GoodJob.{Execution, Job, Job.Query, JobStats, Repo, Web.ChartFormatter}
  import Ecto.Query

  @default_per_page 25

  def load_stats, do: JobStats.stats()

  def load_chart_data do
    JobStats.activity_over_time(24)
    |> ChartFormatter.format_activity_chart()
  end

  def load_nav_counts do
    repo = Repo.repo()
    alias GoodJob.{BatchRecord, Job, Process, SettingSchema}

    %{
      jobs_count: repo.aggregate(Job, :count, :id),
      batches_count: repo.aggregate(BatchRecord, :count, :id),
      cron_entries_count: length(GoodJob.Config.cron_entries()),
      pauses_count:
        repo.aggregate(
          from(s in SettingSchema, where: fragment("? LIKE ?", s.key, "pause:%")),
          :count,
          :id
        ),
      processes_count: repo.aggregate(Process, :count, :id),
      discarded_count: repo.aggregate(Job.discarded(Job), :count, :id)
    }
  end

  def load_jobs(opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, @default_per_page)
    state = Keyword.get(opts, :state)
    queue = Keyword.get(opts, :queue)
    job_class = Keyword.get(opts, :job_class)
    search = Keyword.get(opts, :search)

    query = Job |> order_by([j], desc: j.inserted_at)

    query = apply_state_filter(query, state)
    query = apply_queue_filter(query, queue)
    query = apply_job_class_filter(query, job_class)
    query = apply_search_filter(query, search)

    # Get total count before pagination
    total_count = Repo.repo().aggregate(query, :count, :id)

    # Apply pagination
    offset_value = (page - 1) * per_page

    jobs =
      query
      |> limit(^per_page)
      |> offset(^offset_value)
      |> Repo.repo().all()

    {jobs, total_count}
  end

  def load_executions(active_job_id) do
    Execution
    |> where([e], e.active_job_id == ^active_job_id)
    |> order_by([e], desc: e.inserted_at)
    |> Repo.repo().all()
  end

  def load_queue_stats do
    queues =
      Job
      |> distinct([j], j.queue_name)
      |> select([j], j.queue_name)
      |> Repo.repo().all()
      |> Enum.reject(&is_nil/1)

    Enum.map(queues, fn queue ->
      base_query = from(j in Job) |> Query.in_queue(queue)

      %{
        queue: queue,
        queued: JobStats.count_queued(base_query),
        running: JobStats.count_running(base_query),
        succeeded: JobStats.count_succeeded(base_query),
        discarded: JobStats.count_discarded(base_query)
      }
    end)
  end

  def load_cron_entries do
    entries = GoodJob.Config.cron_entries()

    Enum.map(entries, fn entry ->
      enabled = GoodJob.SettingManager.cron_key_enabled?(entry.key)
      %{entry | enabled: enabled}
    end)
  end

  def get_cron_entry(cron_key) do
    GoodJob.Config.cron_entries()
    |> Enum.find(&(&1.key == cron_key))
  end

  def load_pauses do
    repo = Repo.repo()
    alias GoodJob.SettingSchema

    repo.all(
      from(s in SettingSchema,
        where: fragment("? LIKE ?", s.key, "pause:%")
      )
    )
    |> Enum.map(fn setting ->
      value = setting.value || %{}

      %{
        key: setting.key,
        queue: Map.get(value, "queue") || Map.get(value, :queue),
        job_class: Map.get(value, "job_class") || Map.get(value, :job_class),
        inserted_at: setting.inserted_at
      }
    end)
  end

  def load_batches(opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, @default_per_page)
    alias GoodJob.BatchRecord

    query = BatchRecord |> order_by([b], desc: b.inserted_at)

    total_count = Repo.repo().aggregate(query, :count, :id)

    offset_value = (page - 1) * per_page

    batches =
      query
      |> limit(^per_page)
      |> offset(^offset_value)
      |> Repo.repo().all()

    {batches, total_count}
  end

  def load_processes do
    alias GoodJob.Process
    Repo.repo().all(Process.active())
  end

  # Private helpers

  defp apply_state_filter(query, nil), do: query

  defp apply_state_filter(query, state) do
    case state do
      "queued" -> Job.queued(query)
      "running" -> Job.running(query)
      "succeeded" -> Job.succeeded(query)
      "discarded" -> Job.discarded(query)
      "scheduled" -> Job.scheduled(query)
      _ -> query
    end
  end

  defp apply_queue_filter(query, nil), do: query
  defp apply_queue_filter(query, queue), do: Job.in_queue(query, queue)

  defp apply_job_class_filter(query, nil), do: query
  defp apply_job_class_filter(query, job_class), do: Job.with_job_class(query, job_class)

  defp apply_search_filter(query, nil), do: query

  defp apply_search_filter(query, search) do
    search_like = "%#{search}%"

    where(
      query,
      [j],
      ilike(j.job_class, ^search_like) or
        ilike(fragment("CAST(? AS TEXT)", j.serialized_params), ^search_like)
    )
  end
end
