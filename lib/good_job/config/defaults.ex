defmodule GoodJob.Config.Defaults do
  @moduledoc """
  Default configuration values for GoodJob.
  """

  @defaults %{
    execution_mode: :external,
    queues: "*",
    max_processes: 5,
    poll_interval: 10,
    max_cache: 10_000,
    enable_listen_notify: true,
    enable_cron: false,
    preserve_job_records: true,
    retry_on_unhandled_error: false,
    cleanup_interval_seconds: 600,
    cleanup_interval_jobs: 1_000,
    shutdown_timeout: -1,
    enqueue_after_transaction_commit: false,
    plugins: [],
    database_pool_size: nil,
    database_statement_timeout: nil,
    database_lock_timeout: nil,
    notifier_pool_size: 1,
    notifier_channel: "good_job",
    notifier_wait_interval: 1_000,
    notifier_keepalive_interval: 10_000,
    queue_select_limit: nil,
    cleanup_discarded_jobs: true,
    cleanup_preserved_jobs_before_seconds_ago: 1_209_600,
    enable_pauses: false,
    advisory_lock_heartbeat: false,
    external_jobs: %{}
  }

  @doc """
  Returns the default configuration map.
  """
  def defaults, do: @defaults

  @doc """
  Returns a specific default value.
  """
  def get(key), do: Map.get(@defaults, key)

  @doc """
  Merges defaults into a configuration map.
  """
  def merge(config), do: Map.merge(@defaults, config)
end
