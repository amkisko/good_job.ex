defmodule HabitTrackerWeb.JobsLive do
  @moduledoc """
  LiveView for monitoring GoodJob jobs.
  """
  use HabitTrackerWeb, :live_view

  alias GoodJob.{Job, Repo}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(filter_state: nil, filter_queue: nil)

    if connected?(socket) do
      # Subscribe to PubSub for real-time job updates
      Phoenix.PubSub.subscribe(HabitTracker.PubSub, "good_job:jobs")

      # Keep polling as a fallback (less frequent - every 10 seconds)
      schedule_refresh()
    end

    {:ok, load_data(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Fallback polling - refresh every 10 seconds as safety net
    schedule_refresh()
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_info({event, _job_id}, socket)
      when event in [:job_created, :job_updated, :job_completed, :job_deleted, :job_retried] do
    # Real-time update from PubSub - refresh immediately when jobs change
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("delete_job", params, socket) do
    # Handle both "job_id" and "job-id" (Phoenix may convert underscores to hyphens)
    job_id = Map.get(params, "job_id") || Map.get(params, "job-id")

    unless job_id do
      {:noreply, put_flash(socket, :error, "Missing job_id parameter")}
    else
      case Job.find_by_id(job_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "Job not found")}

        job ->
          case Job.delete(job) do
            {:ok, _} ->
              {:noreply,
               socket
               |> put_flash(:info, "Job deleted successfully")
               |> load_data()}

            {:error, changeset} ->
              {:noreply,
               put_flash(socket, :error, "Failed to delete job: #{inspect(changeset.errors)}")}
          end
      end
    end
  end

  @impl true
  def handle_event("retry_job", params, socket) do
    # Handle both "job_id" and "job-id" (Phoenix may convert underscores to hyphens)
    job_id = Map.get(params, "job_id") || Map.get(params, "job-id")

    unless job_id do
      {:noreply, put_flash(socket, :error, "Missing job_id parameter")}
    else
      case Job.find_by_id(job_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "Job not found")}

        job ->
          case Job.retry(job) do
            {:ok, _updated_job} ->
              {:noreply,
               socket
               |> put_flash(:info, "Job retried successfully")
               |> load_data()}

            {:error, changeset} ->
              {:noreply,
               put_flash(socket, :error, "Failed to retry job: #{inspect(changeset.errors)}")}
          end
      end
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    state = Map.get(params, "state", "")
    queue = Map.get(params, "queue", "")

    socket =
      socket
      |> assign(
        filter_state: if(state == "", do: nil, else: state),
        filter_queue: if(queue == "", do: nil, else: queue)
      )

    {:noreply, load_data(socket)}
  end

  defp load_data(socket) do
    filter_state = Map.get(socket.assigns, :filter_state)
    filter_queue = Map.get(socket.assigns, :filter_queue)

    # Build query with filters
    query =
      Job
      |> apply_state_filter(filter_state)
      |> apply_queue_filter(filter_queue)
      |> order_by([j], desc: j.inserted_at)
      |> limit(50)

    jobs = Repo.repo().all(query)

    # Get job stats using timestamp-based queries
    stats = %{
      queued: Repo.repo().aggregate(Job.queued(Job), :count, :id),
      running: Repo.repo().aggregate(Job.running(Job), :count, :id),
      succeeded: Repo.repo().aggregate(Job.succeeded(Job), :count, :id),
      discarded: Repo.repo().aggregate(Job.discarded(Job), :count, :id),
      scheduled: Repo.repo().aggregate(Job.scheduled(Job), :count, :id)
    }

    assign(socket, jobs: jobs, stats: stats)
  end

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

  defp schedule_refresh do
    # Fallback polling - refresh every 10 seconds as safety net
    # Real-time updates come via PubSub, so polling is just a backup
    Process.send_after(self(), :refresh, 10_000)
  end

  @impl true
  def render(assigns) do
    Phlex.Phoenix.to_rendered(
      HabitTrackerWeb.Components.Jobs.render(assigns)
    )
  end
end
