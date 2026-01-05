defmodule MonorepoExample.Jobs.ProcessJob do
  @moduledoc """
  Job that processes work enqueued from Ruby Rails app.

  This job handles "ElixirProcessedJob" from Ruby. The mapping is configured
  in `config/config.exs` using `external_jobs`:

      config :good_job, :config,
        external_jobs: %{
          "ElixirProcessedJob" => MonorepoExample.Jobs.ProcessJob
        }

  GoodJob.ex automatically converts ActiveJob keyword arguments to a map,
  so you can write your job naturally in Elixir style.
  """
  use GoodJob.Job

  @impl GoodJob.Behaviour
  def perform(%{user_id: user_id, action: action}) do
    # GoodJob.ex automatically converts ActiveJob keyword arguments to a map
    # perform_later(user_id: 123, action: "process") becomes %{user_id: 123, action: "process"}
    IO.puts("[Elixir Worker] Processing job for user_id=#{user_id}, action=#{action}")

    # Simulate some work
    Process.sleep(100)

    # Log the result
    require Logger
    Logger.info("Processed job: user_id=#{user_id}, action=#{action}")

    :ok
  end

  # Fallback for different argument formats (backwards compatibility)
  def perform(args) when is_map(args) do
    user_id = Map.get(args, :user_id) || Map.get(args, "user_id") || 123
    action = Map.get(args, :action) || Map.get(args, "action") || "process"
    perform(%{user_id: user_id, action: action})
  end
end
