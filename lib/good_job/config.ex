defmodule GoodJob.Config do
  @moduledoc """
  Configuration management for GoodJob.

  Configuration can be set via:
  1. Application config (`config/config.exs`)
  2. Environment variables
  3. Runtime configuration

  ## Configuration Options

    * `:repo` - Ecto repository module (required)
    * `:execution_mode` - Execution mode (`:external`, `:async`, `:async_all`, `:async_server`, `:inline`)
      - `:inline` - Execute immediately in current process (test/dev only)
      - `:async` / `:async_server` - Execute in processes within web server process only
      - `:async_all` - Execute in processes in any process
      - `:external` - Enqueue only, requires separate worker process (production default)
    * `:queues` - Queue configuration string (default: `"*"`)
    * `:max_processes` - Maximum concurrent processes per scheduler (default: `5`)
      Environment variable: `GOOD_JOB_MAX_PROCESSES`
    * `:poll_interval` - Poll interval in seconds (default: `10`, `-1` in dev async mode for continuous polling)
    * `:max_cache` - Maximum scheduled jobs to cache (default: `10_000`)
    * `:enable_listen_notify` - Enable LISTEN/NOTIFY (default: `true`)
    * `:enable_cron` - Enable cron jobs (default: `false`)
    * `:preserve_job_records` - Preserve job records (default: `true`)
    * `:retry_on_unhandled_error` - Retry on unhandled errors (default: `false`)
    * `:cleanup_interval_seconds` - Cleanup interval in seconds (default: `600`)
    * `:cleanup_interval_jobs` - Cleanup interval in jobs (default: `1_000`)
    * `:shutdown_timeout` - Shutdown timeout in seconds (default: `-1`)
    * `:enqueue_after_transaction_commit` - Enqueue jobs after transaction commit (default: `false`)
    * `:plugins` - List of plugins to start (default: `[]`)
    * `:database_pool_size` - Database connection pool size for job processing (default: `nil`, uses repo's pool_size)
    * `:database_statement_timeout` - PostgreSQL statement timeout in milliseconds (default: `nil`, no timeout)
    * `:database_lock_timeout` - PostgreSQL lock timeout in milliseconds (default: `nil`, no timeout)
    * `:notifier_pool_size` - Connection pool size for LISTEN/NOTIFY (default: `1`)
    * `:notifier_channel` - PostgreSQL channel name for LISTEN/NOTIFY (default: `"good_job"`)
    * `:notifier_wait_interval` - Wait interval for NOTIFY in milliseconds (default: `1_000`)
    * `:notifier_keepalive_interval` - Keepalive interval in milliseconds (default: `10_000`)
    * `:queue_select_limit` - Number of jobs to query before acquiring advisory locks (default: `nil`, no limit)
    * `:cleanup_discarded_jobs` - Whether to automatically destroy discarded jobs (default: `true`)
    * `:cleanup_preserved_jobs_before_seconds_ago` - Seconds to preserve jobs before cleanup (default: `1_209_600` = 14 days)
    * `:enable_pauses` - Whether job processing can be paused (default: `false`)
    * `:advisory_lock_heartbeat` - Whether to use advisory lock for process heartbeat (default: `false`)
    * `:external_jobs` - Map of external job class names (strings) to Elixir modules (atoms) for cross-language job resolution (default: `%{}`)
      Only needed for jobs enqueued from external languages (e.g., Ruby Rails, Zig). Elixir-native jobs are automatically resolved by module name at runtime.
      Example: `%{"ElixirProcessedJob" => MyApp.Jobs.ProcessJob}`
  """

  alias GoodJob.Config.{Defaults, Env, Validation}

  # Capture environment at compile time
  @compile_env if Code.ensure_loaded?(Mix), do: Mix.env(), else: :prod

  @type t :: %{
          repo: module(),
          execution_mode: :external | :async | :async_all | :async_server | :inline,
          queues: String.t(),
          max_processes: pos_integer(),
          poll_interval: integer(),
          max_cache: non_neg_integer(),
          enable_listen_notify: boolean(),
          enable_cron: boolean(),
          preserve_job_records: boolean(),
          retry_on_unhandled_error: boolean(),
          cleanup_interval_seconds: pos_integer(),
          cleanup_interval_jobs: pos_integer(),
          shutdown_timeout: integer(),
          enqueue_after_transaction_commit: boolean(),
          plugins: list(),
          database_pool_size: pos_integer() | nil,
          database_statement_timeout: pos_integer() | nil,
          database_lock_timeout: pos_integer() | nil,
          notifier_pool_size: pos_integer(),
          notifier_channel: String.t(),
          notifier_wait_interval: pos_integer(),
          notifier_keepalive_interval: pos_integer(),
          cron: map() | nil,
          cron_graceful_restart_period: pos_integer() | nil,
          queue_select_limit: pos_integer() | nil,
          cleanup_discarded_jobs: boolean(),
          cleanup_preserved_jobs_before_seconds_ago: pos_integer(),
          enable_pauses: boolean(),
          advisory_lock_heartbeat: boolean(),
          external_jobs: map()
        }

  @doc """
  Returns the current configuration.
  """
  def config do
    config_data = Application.get_env(:good_job, :config, %{})

    # Convert keyword list to map if needed (recursively for nested structures)
    config_map = normalize_config(config_data)

    config_map
    |> Env.merge_env_vars()
    |> Defaults.merge()
    |> Validation.validate!()
  end

  # Recursively convert keyword lists to maps
  defp normalize_config(data) when is_list(data) do
    Enum.into(data, %{}, fn
      {key, value} when is_list(value) and is_tuple(hd(value)) ->
        {key, normalize_config(value)}

      {key, value} ->
        {key, value}
    end)
  end

  defp normalize_config(data) when is_map(data) do
    Enum.into(data, %{}, fn
      {key, value} when is_list(value) and is_tuple(hd(value)) ->
        {key, normalize_config(value)}

      {key, value} ->
        {key, value}
    end)
  end

  defp normalize_config(data), do: data

  @doc """
  Returns a specific configuration value.
  """
  def get(key, default \\ nil) do
    config()
    |> Map.get(key, default)
  end

  @doc """
  Returns the repository module.
  """
  def repo do
    config()[:repo] || raise "GoodJob repo not configured. Set config :good_job, repo: MyApp.Repo"
  end

  @doc """
  Returns the execution mode.

  Valid modes (aligned with Ruby GoodJob):
  - `:inline` - Execute immediately in current process (test/dev only)
  - `:async` / `:async_server` - Execute in processes within web server process only
  - `:async_all` - Execute in processes in any process
  - `:external` - Enqueue only, requires separate worker process (production default)

  `:async_server` is an alias for `:async`.
  """
  def execution_mode do
    mode = get(:execution_mode, Defaults.get(:execution_mode))

    # Normalize async_server to async (they're equivalent)
    case mode do
      :async_server -> :async
      other -> other
    end
  end

  @doc """
  Returns the queue configuration string.
  """
  def queues do
    get(:queues, Defaults.get(:queues))
  end

  @doc """
  Returns the maximum concurrent processes per scheduler.
  """
  def max_processes do
    get(:max_processes, Defaults.get(:max_processes))
  end

  @doc """
  Returns the maximum cache size.
  """
  def max_cache do
    get(:max_cache, Defaults.get(:max_cache))
  end

  @doc """
  Returns whether LISTEN/NOTIFY is enabled.
  """
  def enable_listen_notify? do
    get(:enable_listen_notify, Defaults.get(:enable_listen_notify))
  end

  @doc """
  Returns whether cron is enabled.
  """
  def enable_cron? do
    cron = cron()
    get(:enable_cron, Defaults.get(:enable_cron)) && map_size(cron) > 0
  end

  @doc """
  Returns the cron configuration.
  """
  def cron do
    get(:cron, %{})
  end

  alias GoodJob.Cron.Entry

  @doc """
  Returns cron entries parsed from configuration.

  Validates all entries and raises if any are invalid.
  """
  def cron_entries do
    cron()
    |> Enum.map(fn {key, params} ->
      # Convert params to keyword list if it's a map
      params_list =
        case params do
          params when is_map(params) -> Map.to_list(params)
          params when is_list(params) -> params
          _ -> []
        end

      params_list
      |> Keyword.put(:key, key)
      |> Entry.new()
    end)
  end

  @doc """
  Validates cron configuration.

  Returns `:ok` if valid, `{:error, reason}` if invalid.
  """
  def validate_cron do
    entries = cron_entries()

    # Check for duplicate keys
    keys = Enum.map(entries, & &1.key)

    if length(keys) != length(Enum.uniq(keys)) do
      duplicates = keys -- Enum.uniq(keys)
      {:error, "Duplicate cron entry keys: #{inspect(Enum.uniq(duplicates))}"}
    else
      :ok
    end
  rescue
    e in ArgumentError ->
      {:error, Exception.message(e)}
  end

  @doc """
  Returns the graceful restart period for cron jobs (in seconds).
  """
  def cron_graceful_restart_period do
    get(:cron_graceful_restart_period, nil)
  end

  @doc """
  Returns whether job records should be preserved.
  """
  def preserve_job_records? do
    get(:preserve_job_records, Defaults.get(:preserve_job_records))
  end

  @doc """
  Returns whether to retry on unhandled errors.
  """
  def retry_on_unhandled_error? do
    get(:retry_on_unhandled_error, Defaults.get(:retry_on_unhandled_error))
  end

  @doc """
  Returns the cleanup interval in seconds.
  """
  def cleanup_interval_seconds do
    get(:cleanup_interval_seconds, Defaults.get(:cleanup_interval_seconds))
  end

  @doc """
  Returns the cleanup interval in jobs.
  """
  def cleanup_interval_jobs do
    get(:cleanup_interval_jobs, Defaults.get(:cleanup_interval_jobs))
  end

  @doc """
  Returns the shutdown timeout in seconds.
  """
  def shutdown_timeout do
    get(:shutdown_timeout, Defaults.get(:shutdown_timeout))
  end

  @doc """
  Returns whether to enqueue jobs after transaction commit.
  """
  def enqueue_after_transaction_commit? do
    get(:enqueue_after_transaction_commit, Defaults.get(:enqueue_after_transaction_commit))
  end

  @doc """
  Returns the list of configured plugins.
  """
  def plugins do
    plugins = get(:plugins, Defaults.get(:plugins))
    # Convert map to list if needed (normalize_config converts keyword lists to maps)
    if is_map(plugins) do
      Enum.to_list(plugins)
    else
      plugins
    end
  end

  @doc """
  Returns whether GoodJob should start automatically based on execution_mode.

  GoodJob starts automatically when:
  - execution_mode is `:async` or `:async_server` (starts in web server process only)
  - execution_mode is `:async_all` (starts in any process)
  - execution_mode is `:external` AND NOT running in web server process.

  When execution_mode is `:external` and running in web server process, GoodJob should not start
  (e.g., when running Phoenix web server separately from worker).

  Behavior:
  - `:async` / `:async_server` mode: GoodJob starts automatically in the web server process only
  - `:async_all` mode: GoodJob starts automatically in any process
  - `:external` mode: GoodJob runs in a separate process (via `good_job start` command)
  - `:inline` mode: GoodJob does not start automatically (used for testing)
  """
  def start_in_application? do
    case execution_mode() do
      :async ->
        # Only start in web server process
        in_webserver?()

      :async_all ->
        # Start in any process
        true

      :external ->
        # In external mode, only start if NOT in web server process
        !in_webserver?()

      :inline ->
        # Inline mode is for testing, don't start automatically
        false

      _ ->
        false
    end
  end

  @doc """
  Returns whether we're running in a web server process.

  This can be used to determine if GoodJob should start in external mode.
  In external mode, GoodJob typically should NOT start in web server processes.

  Detects web server mode by checking if Phoenix is configured to serve endpoints
  (which happens when running `mix phx.server`).
  """
  def in_webserver? do
    # Check if Phoenix is configured to serve endpoints
    # mix phx.server sets :phoenix, :serve_endpoints to true
    case Application.get_env(:phoenix, :serve_endpoints) do
      true -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Returns the database connection pool size for job processing.

  Returns `nil` if not configured (uses repo's pool_size).
  """
  def database_pool_size do
    get(:database_pool_size, Defaults.get(:database_pool_size))
  end

  @doc """
  Returns the PostgreSQL statement timeout in milliseconds.

  Returns `nil` if not configured (no timeout).
  """
  def database_statement_timeout do
    get(:database_statement_timeout, Defaults.get(:database_statement_timeout))
  end

  @doc """
  Returns the PostgreSQL lock timeout in milliseconds.

  Returns `nil` if not configured (no timeout).
  """
  def database_lock_timeout do
    get(:database_lock_timeout, Defaults.get(:database_lock_timeout))
  end

  @doc """
  Returns the connection pool size for LISTEN/NOTIFY.

  Defaults to 1 (single dedicated connection).
  """
  def notifier_pool_size do
    get(:notifier_pool_size, Defaults.get(:notifier_pool_size))
  end

  @doc """
  Returns the PostgreSQL channel name for LISTEN/NOTIFY.

  Defaults to "good_job".
  """
  def notifier_channel do
    get(:notifier_channel, Defaults.get(:notifier_channel))
  end

  @doc """
  Returns the wait interval for NOTIFY in milliseconds.

  Defaults to 1_000 (1 second).
  """
  def notifier_wait_interval do
    get(:notifier_wait_interval, Defaults.get(:notifier_wait_interval))
  end

  @doc """
  Returns the keepalive interval for LISTEN/NOTIFY connection in milliseconds.

  Defaults to 10_000 (10 seconds).
  """
  def notifier_keepalive_interval do
    get(:notifier_keepalive_interval, Defaults.get(:notifier_keepalive_interval))
  end

  @doc """
  Returns the queue select limit (number of jobs to query before acquiring advisory locks).

  Returns `nil` if not configured (no limit).
  This limit helps avoid locking too many rows when selecting eligible jobs from large queues.
      Should be higher than total concurrent processes across all good_job schedulers.
  """
  def queue_select_limit do
    get(:queue_select_limit, Defaults.get(:queue_select_limit))
  end

  @doc """
  Returns whether to automatically destroy discarded jobs that have been preserved.

  Defaults to `true`.
  """
  def cleanup_discarded_jobs? do
    get(:cleanup_discarded_jobs, Defaults.get(:cleanup_discarded_jobs))
  end

  @doc """
  Returns the number of seconds to preserve jobs before automatic destruction.

  Defaults to 1,209,600 (14 days).
  """
  def cleanup_preserved_jobs_before_seconds_ago do
    get(:cleanup_preserved_jobs_before_seconds_ago, Defaults.get(:cleanup_preserved_jobs_before_seconds_ago))
  end

  @doc """
  Returns whether job processing can be paused.

  Defaults to `false`.
  When enabled, allows pausing jobs by queue, job class, or label.
  """
  def enable_pauses? do
    get(:enable_pauses, Defaults.get(:enable_pauses))
  end

  @doc """
  Returns whether to take an advisory lock on the process record in the notifier reactor.

  Defaults to `true` in development, `false` otherwise.
  Used to determine if an execution process is active.
  """
  @dialyzer {:nowarn_function, advisory_lock_heartbeat?: 0}
  def advisory_lock_heartbeat? do
    case get(:advisory_lock_heartbeat) do
      nil ->
        @compile_env == :dev

      value ->
        value
    end
  end

  @doc """
  Returns the poll interval in seconds, with development-specific behavior.

  In development with async mode, defaults to -1 (continuous polling).
  Otherwise defaults to 10 seconds.
  """
  @dialyzer {:nowarn_function, poll_interval: 0}
  def poll_interval do
    base_interval = get(:poll_interval, Defaults.get(:poll_interval))
    env_is_dev = @compile_env == :dev
    mode = execution_mode()
    is_async_mode = mode in [:async, :async_all, :async_server]

    if env_is_dev && is_async_mode do
      -1
    else
      base_interval
    end
  end

  @doc """
  Returns the external job class name to Elixir module mapping.

  This map allows you to explicitly configure which Elixir module should handle
  each external job class name. This is only needed for cross-language job processing
  (jobs enqueued from external languages, e.g., Ruby Rails, Zig).

  Elixir-native jobs (enqueued from Elixir code) are automatically resolved by
  module name at runtime. No configuration is needed for them.

  Example:
      config :good_job, :config,
        external_jobs: %{
          "ElixirProcessedJob" => MyApp.Jobs.ProcessJob,
          "MyRailsJob" => MyApp.Jobs.MyElixirJob
        }

  Defaults to an empty map `%{}`.
  """
  def external_jobs do
    get(:external_jobs, Defaults.get(:external_jobs))
  end
end
