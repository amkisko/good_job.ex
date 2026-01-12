defmodule GoodJob.Application do
  @moduledoc """
  OTP Application for GoodJob.

  This module starts the GoodJob supervision tree.

  The application will only start GoodJob.Supervisor automatically when
  `execution_mode` is set to `:async`.
  When `execution_mode` is `:external`, GoodJob must be started manually
  (e.g., via a separate process or CLI command).

  Behavior:
  - `:async` mode: GoodJob starts automatically in the web server process only
  - `:external` mode: GoodJob runs in a separate process (via `good_job start` command)
  - `:inline` mode: GoodJob does not start automatically (used for testing)
  """

  use Application

  @impl true
  def start(_type, _args) do
    # For :async mode, GoodJob should be started by the main application
    # (e.g., HabitTracker.Application) after the repo is available.
    # GoodJob.Application starts before the main app, so the repo isn't available yet.
    #
    # For :external mode, GoodJob should be started manually (e.g., via CLI).
    #
    # In test mode, start the test repo if configured
    children =
      if Mix.env() == :test and Application.get_env(:good_job, GoodJob.TestRepo) do
        [GoodJob.TestRepo]
      else
        []
      end

    opts = [strategy: :one_for_one, name: GoodJob.ApplicationSupervisor]
    Supervisor.start_link(children, opts)
  end
end
