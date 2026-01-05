defmodule MonorepoExample.Jobs.ZigJob do
  @moduledoc """
  Job that processes work enqueued from Elixir for Zig worker.

  This job is enqueued with job_class "Elixir.MonorepoExample.Jobs.ZigJob"
  and will be processed by the Zig worker.
  """
  use GoodJob.Job, queue: "zig.default"

  @impl GoodJob.Behaviour
  def perform(%{message: message}) do
    # This job is just a descriptor - the actual processing happens in Zig
    # GoodJob.ex will serialize this and store it in the database
    # The Zig worker will pick it up and process it
    require Logger
    Logger.info("ZigJob enqueued (will be processed by Zig worker): #{message}")
    :ok
  end

  # Fallback for different argument formats
  def perform(args) when is_map(args) do
    message = Map.get(args, :message) || Map.get(args, "message") || "Hello from Elixir"
    perform(%{message: message})
  end
end
