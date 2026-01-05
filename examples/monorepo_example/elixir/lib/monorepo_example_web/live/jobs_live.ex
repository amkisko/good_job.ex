defmodule MonorepoExampleWeb.JobsLive do
  @moduledoc """
  LiveView for monitoring GoodJob jobs and enqueueing new jobs.
  """
  use MonorepoExampleWeb, :live_view

  alias GoodJob.{Job, Repo}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to PubSub for real-time job updates
      Phoenix.PubSub.subscribe(MonorepoExample.PubSub, "good_job:jobs")

      # Keep polling as a fallback (every 10 seconds)
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
      when event in [:job_created, :job_updated, :job_completed, :job_deleted, :job_retried, :job_discarded] do
    # Real-time update from PubSub - refresh immediately when jobs change
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("enqueue_elixir", _params, socket) do
    # Enqueue an Elixir job
    case MonorepoExample.Jobs.ScheduledElixirJob.perform_later(%{
           message: "Enqueued from Elixir web interface at #{DateTime.utc_now()}"
         }) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Elixir job enqueued successfully!")
         |> load_data()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to enqueue job: #{inspect(reason)}")
         |> load_data()}
    end
  end

  @impl true
  def handle_event("enqueue_ruby", _params, socket) do
    # Enqueue a Ruby job using the descriptor module
    case MonorepoExample.Jobs.ExampleRubyJob.perform_later(%{
           message: "Enqueued from Elixir web interface at #{DateTime.utc_now()}"
         }) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ruby job enqueued successfully!")
         |> load_data()}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to enqueue Ruby job: #{inspect(reason)}")
         |> load_data()}
    end
  end

  defp load_data(socket) do
    # Get recent jobs
    jobs =
      Job
      |> order_by([j], desc: j.inserted_at)
      |> limit(50)
      |> Repo.repo().all()

    # Get job stats
    stats = %{
      queued: Repo.repo().aggregate(Job.queued(Job), :count, :id),
      running: Repo.repo().aggregate(Job.running(Job), :count, :id),
      succeeded: Repo.repo().aggregate(Job.succeeded(Job), :count, :id),
      discarded: Repo.repo().aggregate(Job.discarded(Job), :count, :id),
      scheduled: Repo.repo().aggregate(Job.scheduled(Job), :count, :id)
    }

    # Get CSRF token for forms
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    assign(socket, jobs: jobs, stats: stats, csrf_token: csrf_token)
  end

  defp schedule_refresh do
    # Poll every 10 seconds as a fallback (PubSub handles real-time updates)
    Process.send_after(self(), :refresh, 10_000)
  end

  @impl true
  def render(assigns) do
    Phlex.Phoenix.to_rendered(
      MonorepoExampleWeb.Components.JobsPage.render(assigns)
    )
  end
end
