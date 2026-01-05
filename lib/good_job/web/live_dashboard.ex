defmodule GoodJob.Web.LiveDashboard do
  @moduledoc """
  Standalone Phoenix LiveView dashboard for monitoring GoodJob.

  This module provides a standalone web-based dashboard for monitoring job queues, viewing job status,
  and managing GoodJob. For integration with Phoenix LiveDashboard, use `GoodJob.Web.LiveDashboardPage` instead.

  ## Installation

  Option 1: Standalone dashboard (this module)

      scope "/good_job" do
        pipe_through :browser

        live "/", GoodJob.Web.LiveDashboard, :index
        live "/jobs", GoodJob.Web.LiveDashboard, :jobs
        live "/jobs/:id", GoodJob.Web.LiveDashboard, :job_detail
      end

  Option 2: Phoenix LiveDashboard integration (recommended)

      import Phoenix.LiveDashboard.Router

      live_dashboard "/dashboard",
        metrics: MyAppWeb.Telemetry,
        additional_pages: [
          good_job: GoodJob.Web.LiveDashboardPage
        ]

  ## Features

  - Real-time job queue monitoring
  - Job status overview
  - Job detail view
  - Queue statistics
  - Job filtering and search
  """

  use Phoenix.LiveView

  alias GoodJob.{Job, JobStats, Repo}
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_refresh()
    end

    {:ok, assign(socket, stats: load_stats(), jobs: [], page: 1, per_page: 50)}
  end

  @impl true
  def handle_params(%{"view" => "jobs"} = params, _uri, socket) do
    page = String.to_integer(params["page"] || "1")
    per_page = String.to_integer(params["per_page"] || "50")
    state = params["state"]
    queue = params["queue"]

    jobs = load_jobs(page: page, per_page: per_page, state: state, queue: queue)

    {:noreply, assign(socket, jobs: jobs, page: page, per_page: per_page, state: state, queue: queue)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    job = Job.find_by_id(id)

    {:noreply, assign(socket, job: job)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    stats = load_stats()
    jobs = if socket.assigns[:jobs], do: load_jobs(socket.assigns), else: []

    {:noreply, assign(socket, stats: stats, jobs: jobs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="good-job-dashboard">
      <header>
        <h1>GoodJob Dashboard</h1>
      </header>

      <nav>
        <.link navigate="/good_job">Overview</.link>
        <.link navigate="/good_job/jobs">Jobs</.link>
      </nav>

      <main>
        <%= cond do %>
          <% assigns[:job] -> %>
            <.job_detail job={assigns.job} />
          <% assigns[:jobs] -> %>
            <.jobs_list jobs={assigns.jobs} page={assigns.page} />
          <% true -> %>
            <.overview stats={assigns.stats} />
        <% end %>
      </main>
    </div>
    """
  end

  defp overview(assigns) do
    ~H"""
    <div class="overview">
      <h2>Overview</h2>
      <div class="stats-grid">
        <div class="stat-card">
          <h3>Available</h3>
          <p><%= @stats.available %></p>
        </div>
        <div class="stat-card">
          <h3>Executing</h3>
          <p><%= @stats.executing %></p>
        </div>
        <div class="stat-card">
          <h3>Completed</h3>
          <p><%= @stats.completed %></p>
        </div>
        <div class="stat-card">
          <h3>Retryable</h3>
          <p><%= @stats.retryable %></p>
        </div>
        <div class="stat-card">
          <h3>Discarded</h3>
          <p><%= @stats.discarded %></p>
        </div>
      </div>
    </div>
    """
  end

  defp jobs_list(assigns) do
    ~H"""
    <div class="jobs-list">
      <h2>Jobs</h2>
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Queue</th>
            <th>State</th>
            <th>Job Class</th>
            <th>Created At</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <%= for job <- @jobs do %>
            <tr>
              <td><%= String.slice(job.id, 0..8) %>...</td>
              <td><%= job.queue_name %></td>
              <td><%= GoodJob.Job.calculate_state(job) %></td>
              <td><%= job.job_class %></td>
              <td><%= job.inserted_at %></td>
              <td>
                <.link navigate={"/good_job/jobs/#{job.id}"}>View</.link>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp job_detail(assigns) do
    ~H"""
    <div class="job-detail">
      <h2>Job Details</h2>
      <dl>
        <dt>ID</dt>
        <dd><%= @job.id %></dd>
        <dt>State</dt>
        <dd><%= GoodJob.Job.calculate_state(@job) %></dd>
        <dt>Queue</dt>
        <dd><%= @job.queue_name %></dd>
        <dt>Job Class</dt>
        <dd><%= @job.job_class %></dd>
        <dt>Created At</dt>
        <dd><%= @job.inserted_at %></dd>
        <%= if @job.error do %>
          <dt>Error</dt>
          <dd><pre><%= @job.error %></pre></dd>
        <% end %>
      </dl>
    </div>
    """
  end

  defp load_stats do
    JobStats.stats()
  end

  defp load_jobs(opts) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)
    state = Keyword.get(opts, :state)
    queue = Keyword.get(opts, :queue)

    query = Job |> order_by([j], desc: j.inserted_at)

    query =
      if state do
        # Filter by calculated state using timestamp fields
        case state do
          "queued" -> Job.queued(query)
          "running" -> Job.running(query)
          "succeeded" -> Job.succeeded(query)
          "discarded" -> Job.discarded(query)
          _ -> query
        end
      else
        query
      end

    query =
      if queue do
        Job.in_queue(query, queue)
      else
        query
      end

    offset_value = (page - 1) * per_page

    query
    |> limit(^per_page)
    |> offset(^offset_value)
    |> Repo.repo().all()
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, 5_000)
  end
end
