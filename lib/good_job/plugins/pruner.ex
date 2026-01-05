defmodule GoodJob.Plugins.Pruner do
  @moduledoc """
  Built-in plugin that periodically prunes old job records.

  This plugin automatically removes completed and discarded jobs older than the configured
  retention period.

  ## Configuration

      config :good_job,
        plugins: [
          {GoodJob.Plugins.Pruner, max_age: 86_400, max_count: 10_000}
        ]

  ## Options

    * `:max_age` - Maximum age in seconds for job records (default: 86_400 = 24 hours)
    * `:max_count` - Maximum number of records to keep (default: 10_000)
    * `:interval` - How often to run pruning in seconds (default: 600 = 10 minutes)
  """

  @behaviour GoodJob.Plugin

  use GenServer

  require Logger

  alias GoodJob.Cleanup

  @default_max_age 86_400
  @default_max_count 10_000
  @default_interval 600

  @impl GoodJob.Plugin
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GoodJob.Plugin
  def validate(opts) do
    cond do
      opts[:max_age] && not is_integer(opts[:max_age]) ->
        {:error, "expected :max_age to be an integer"}

      opts[:max_count] && not is_integer(opts[:max_count]) ->
        {:error, "expected :max_count to be an integer"}

      opts[:interval] && not is_integer(opts[:interval]) ->
        {:error, "expected :interval to be an integer"}

      true ->
        :ok
    end
  end

  @impl GenServer
  def init(opts) do
    conf = Keyword.fetch!(opts, :conf)
    max_age = Keyword.get(opts, :max_age, @default_max_age)
    max_count = Keyword.get(opts, :max_count, @default_max_count)
    interval = Keyword.get(opts, :interval, @default_interval)

    state = %{
      conf: conf,
      max_age: max_age,
      max_count: max_count,
      interval: interval,
      timer: nil
    }

    {:ok, schedule_prune(state)}
  end

  @impl GenServer
  def handle_info(:prune, state) do
    prune_jobs(state)
    {:noreply, schedule_prune(state)}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_prune(%{interval: interval} = state) do
    timer = Process.send_after(self(), :prune, interval * 1000)
    %{state | timer: timer}
  end

  defp prune_jobs(%{conf: _conf, max_age: max_age, max_count: max_count}) do
    deleted_count =
      Cleanup.cleanup_preserved_jobs(
        older_than: max_age,
        in_batches_of: max_count
      )

    Logger.info("Pruned #{deleted_count} old job records")
    deleted_count
  end
end
