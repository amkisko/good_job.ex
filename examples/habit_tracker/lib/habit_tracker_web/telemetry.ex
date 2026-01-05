defmodule HabitTrackerWeb.Telemetry do
  @moduledoc """
  Telemetry module for HabitTracker.

  This module provides basic telemetry events for Phoenix LiveDashboard.
  """

  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),

      # GoodJob Metrics
      summary("good_job.job.enqueue.duration",
        unit: {:native, :millisecond}
      ),
      summary("good_job.job.execute.duration",
        unit: {:native, :millisecond}
      ),
      counter("good_job.job.enqueue.count"),
      counter("good_job.job.execute.count"),
      counter("good_job.job.success.count"),
      counter("good_job.job.error.count")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {HabitTrackerWeb, :count_users, []}
    ]
  end
end
