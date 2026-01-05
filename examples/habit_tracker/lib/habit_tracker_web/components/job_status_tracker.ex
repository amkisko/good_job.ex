defmodule HabitTrackerWeb.Components.JobStatusTracker do
  @moduledoc """
  Component for tracking and displaying job status in real-time.

  This component polls the database to check job status and displays
  a visual indicator (loader, status badge) for the job lifecycle.
  """

  use Phoenix.LiveComponent

  alias GoodJob.Job

  @refresh_interval 1_000

  @impl true
  def mount(socket) do
    {:ok, assign(socket, status: :unknown, job: nil, error: nil)}
  end

  @impl true
  def update(%{active_job_id: active_job_id} = assigns, socket) when is_binary(active_job_id) do
    if connected?(socket) do
      schedule_refresh()
      job = fetch_job(active_job_id)
      status = determine_status(job)

      {:ok,
       socket
       |> assign(assigns)
       |> assign(status: status, job: job, error: nil)}
    else
      {:ok, assign(socket, assigns)}
    end
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_info(:refresh, socket) do
    active_job_id = socket.assigns.active_job_id

    if active_job_id do
      job = fetch_job(active_job_id)
      status = determine_status(job)

      # Continue polling if job is still in progress
      if status in [:enqueued, :processing] do
        schedule_refresh()
      end

      {:noreply,
       socket
       |> assign(status: status, job: job, error: nil)
       |> push_event("job-status-update", %{status: status})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="job-status-tracker" id={"job-status-#{@id}"}>
      <%= case @status do %>
        <% :unknown -> %>
          <div class="flex items-center gap-2 text-gray-500">
            <div class="w-4 h-4 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin"></div>
            <span class="text-sm">Checking status...</span>
          </div>

        <% :enqueued -> %>
          <div class="flex items-center gap-2 text-blue-600">
            <div class="w-4 h-4 border-2 border-blue-300 border-t-blue-600 rounded-full animate-spin"></div>
            <span class="text-sm font-medium">Enqueued</span>
          </div>

        <% :processing -> %>
          <div class="flex items-center gap-2 text-yellow-600">
            <div class="w-4 h-4 border-2 border-yellow-300 border-t-yellow-600 rounded-full animate-spin"></div>
            <span class="text-sm font-medium">Processing...</span>
          </div>

        <% :completed -> %>
          <div class="flex items-center gap-2 text-green-600">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
            </svg>
            <span class="text-sm font-medium">Completed</span>
          </div>

        <% :failed -> %>
          <div class="flex items-center gap-2 text-red-600">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
            <span class="text-sm font-medium">Failed</span>
            <%= if @job && @job.error do %>
              <span class="text-xs text-red-500 ml-2" title={@job.error}>
                <%= String.slice(@job.error, 0..50) %>...
              </span>
            <% end %>
          </div>

        <% :retryable -> %>
          <div class="flex items-center gap-2 text-orange-600">
            <div class="w-4 h-4 border-2 border-orange-300 border-t-orange-600 rounded-full animate-spin"></div>
            <span class="text-sm font-medium">Retrying...</span>
          </div>

        <% _ -> %>
          <div class="flex items-center gap-2 text-gray-500">
            <span class="text-sm">Unknown status</span>
          </div>
      <% end %>
    </div>
    """
  end

  defp fetch_job(active_job_id) do
    Job.find_by_active_job_id(active_job_id)
  end

  defp determine_status(nil), do: :unknown

  defp determine_status(%Job{} = job) do
    # Use calculate_state to get state from timestamp fields
    case Job.calculate_state(job) do
      :queued -> :enqueued
      :running -> :processing
      :succeeded -> :completed
      :discarded -> :failed
      :scheduled ->
        # Scheduled jobs that are retrying (have error but not finished)
        if not is_nil(job.error) and is_nil(job.finished_at) do
          :retryable
        else
          :enqueued
        end
      _ -> :unknown
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
