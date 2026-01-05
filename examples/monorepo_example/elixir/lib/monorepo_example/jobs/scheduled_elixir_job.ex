defmodule MonorepoExample.Jobs.ScheduledElixirJob do
  @moduledoc """
  Scheduled Elixir job that runs via cron from Elixir side.
  """
  use GoodJob.Job, queue: "ex.default"

  @impl GoodJob.Behaviour
  def perform(%{"message" => message}) do
    IO.puts("[Elixir Cron] ScheduledElixirJob: #{message} at #{DateTime.utc_now()}")

    require Logger
    Logger.info("ScheduledElixirJob executed: #{message} at #{DateTime.utc_now()}")

    :ok
  end

  def perform(%{message: message}) do
    perform(%{"message" => message})
  end

  def perform(args) when is_map(args) do
    message = Map.get(args, "message") || Map.get(args, :message) || "Default message"
    perform(%{"message" => message})
  end
end
