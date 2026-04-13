defmodule GoodJob.IdleShutdown do
  @moduledoc false

  use GenServer
  require Logger

  alias GoodJob.Config

  @check_interval_ms 1_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    GoodJob.IdleTracker.init_started()
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check, state) do
    case Config.idle_timeout() do
      nil ->
        {:noreply, state}

      seconds when is_integer(seconds) and seconds >= 1 ->
        if idle_shutdown?(seconds) do
          Logger.info("GoodJob: idle_timeout (#{seconds}s) reached; stopping GoodJob.Supervisor")
          _ = Supervisor.stop(GoodJob.Supervisor, :normal)
          {:noreply, state}
        else
          schedule_check()
          {:noreply, state}
        end

      _ ->
        schedule_check()
        {:noreply, state}
    end
  end

  defp idle_shutdown?(seconds) do
    if total_running_tasks() > 0 do
      false
    else
      case GoodJob.IdleTracker.last_execution_at() do
        nil -> false
        last -> System.monotonic_time(:second) - last >= seconds
      end
    end
  end

  defp total_running_tasks do
    Registry.select(GoodJob.Registry, [
      {{:_, :"$1", :"$2"}, [{:==, :"$1", {:scheduler, :_}}], [:"$2"]}
    ])
    |> Enum.reduce(0, fn pid, acc ->
      n =
        try do
          case GenServer.call(pid, :get_running_tasks_count, 150) do
            {:ok, count} when is_integer(count) -> count
            _ -> 0
          end
        catch
          _, _ -> 0
        end

      acc + n
    end)
  end

  defp schedule_check do
    Process.send_after(self(), :check, @check_interval_ms)
  end
end
