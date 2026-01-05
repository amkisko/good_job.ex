defmodule HabitTrackerWeb.AnalyticsLive do
  @moduledoc """
  LiveView for displaying analytics and statistics.
  """
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.Analytics
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      schedule_refresh()
    end

    {:ok, load_data(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("calculate_analytics", %{"period" => period}, socket) do
    today = Date.utc_today()

    {start_date, end_date} =
      case period do
        "daily" -> {today, today}
        "weekly" -> {Date.beginning_of_week(today, :monday), Date.end_of_week(today, :monday)}
        "monthly" -> {Date.new!(today.year, today.month, 1), Date.end_of_month(today)}
      end

    # Enqueue analytics job
    # Date structs are automatically serialized in ActiveJob format
    HabitTracker.Jobs.AnalyticsJob.perform_later(%{
      period: period,
      period_start: start_date,
      period_end: end_date
    })

    {:noreply,
     socket
     |> put_flash(:info, "Analytics calculation job enqueued!")
     |> load_data()}
  end

  defp load_data(socket) do
    # Get recent analytics
    analytics =
      from a in Analytics,
        order_by: [desc: a.inserted_at],
        limit: 10

    analytics_list = Repo.all(analytics)

    assign(socket, analytics: analytics_list)
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, 10_000)
  end

  @impl true
  def render(assigns) do
    Phlex.Phoenix.to_rendered(
      HabitTrackerWeb.Components.Analytics.render(assigns)
    )
  end
end
