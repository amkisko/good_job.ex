defmodule MonorepoExample.Jobs.AutoConcurrencyJob do
  use GoodJob.Job, queue: "ex.default"

  def good_job_concurrency_config do
    [total_limit: 2]
  end

  def good_job_concurrency_key(%{user_id: user_id}) do
    "user:#{user_id}"
  end

  def perform(%{user_id: user_id, message: message}) do
    require Logger
    Logger.info("AutoConcurrencyJob: user_id=#{user_id}, message=#{message}")
    IO.puts("[Elixir Worker] AutoConcurrencyJob: user_id=#{user_id}, message=#{message}")
    Process.sleep(2000)
    :ok
  end

  def perform(args) when is_map(args) do
    user_id = Map.get(args, :user_id) || Map.get(args, "user_id") || "unknown"
    message = Map.get(args, :message) || Map.get(args, "message") || "test"
    perform(%{user_id: user_id, message: message})
  end
end
