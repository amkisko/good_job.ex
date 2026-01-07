defmodule MonorepoExample.Jobs.ConcurrencyTestJob do
  use GoodJob.Job, queue: "ex.default"

  @impl GoodJob.Behaviour
  def perform(%{key: key, message: message}) do
    require Logger
    Logger.info("ConcurrencyTestJob: key=#{key}, message=#{message}")
    IO.puts("[Elixir Worker] ConcurrencyTestJob: key=#{key}, message=#{message}")
    Process.sleep(2000)

    :ok
  end

  def perform(args) when is_map(args) do
    key = Map.get(args, :key) || Map.get(args, "key") || "default"
    message = Map.get(args, :message) || Map.get(args, "message") || "test"
    perform(%{key: key, message: message})
  end

  def good_job_concurrency_config do
    [total_limit: 2]
  end
end
