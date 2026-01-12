defmodule GoodJob.Config.Validation do
  @moduledoc """
  Configuration validation logic.
  """

  # Valid execution modes (aligned with Ruby GoodJob)
  @valid_execution_modes [:external, :async, :inline]

  @doc """
  Validates configuration and raises if invalid.
  """
  def validate!(config) do
    validate_repo!(config)
    validate_execution_mode!(config)
    validate_max_processes!(config)
    validate_poll_interval!(config)
    validate_max_cache!(config)
    validate_queues!(config)
    validate_shutdown_timeout!(config)
    validate_cleanup_intervals!(config)
    validate_plugins!(config)
    validate_database_config!(config)
    validate_notifier_config!(config)
    validate_external_jobs!(config)

    config
  end

  defp validate_repo!(config) do
    if config[:repo] == nil do
      raise "GoodJob repo not configured. Set config :good_job, repo: MyApp.Repo"
    end
  end

  defp validate_execution_mode!(config) do
    execution_mode = config[:execution_mode]

    if execution_mode not in @valid_execution_modes do
      raise ArgumentError,
            "GoodJob execution_mode must be one of #{inspect(@valid_execution_modes)}. Got: #{inspect(execution_mode)}"
    end
  end

  defp validate_max_processes!(config) do
    max_processes = config[:max_processes]

    if max_processes && (not is_integer(max_processes) or max_processes < 1) do
      raise ArgumentError,
            "GoodJob max_processes must be a positive integer. Got: #{inspect(max_processes)}"
    end
  end

  defp validate_poll_interval!(config) do
    poll_interval = config[:poll_interval]

    if poll_interval && (not is_integer(poll_interval) or poll_interval < 1) do
      raise ArgumentError,
            "GoodJob poll_interval must be a positive integer (seconds). Got: #{inspect(poll_interval)}"
    end
  end

  defp validate_max_cache!(config) do
    max_cache = config[:max_cache]

    if max_cache && (not is_integer(max_cache) or max_cache < 0) do
      raise ArgumentError,
            "GoodJob max_cache must be a non-negative integer. Got: #{inspect(max_cache)}"
    end
  end

  defp validate_queues!(config) do
    queues = config[:queues]

    if queues && not is_binary(queues) do
      raise ArgumentError,
            "GoodJob queues must be a string. Got: #{inspect(queues)}"
    end
  end

  defp validate_shutdown_timeout!(config) do
    shutdown_timeout = config[:shutdown_timeout]

    if shutdown_timeout && (not is_integer(shutdown_timeout) or shutdown_timeout < -1) do
      raise ArgumentError,
            "GoodJob shutdown_timeout must be an integer >= -1 (-1 means wait forever). Got: #{inspect(shutdown_timeout)}"
    end
  end

  defp validate_cleanup_intervals!(config) do
    cleanup_interval_seconds = config[:cleanup_interval_seconds]

    if cleanup_interval_seconds &&
         (not is_integer(cleanup_interval_seconds) or cleanup_interval_seconds < 1) do
      raise ArgumentError,
            "GoodJob cleanup_interval_seconds must be a positive integer. Got: #{inspect(cleanup_interval_seconds)}"
    end

    cleanup_interval_jobs = config[:cleanup_interval_jobs]

    if cleanup_interval_jobs &&
         (not is_integer(cleanup_interval_jobs) or cleanup_interval_jobs < 1) do
      raise ArgumentError,
            "GoodJob cleanup_interval_jobs must be a positive integer. Got: #{inspect(cleanup_interval_jobs)}"
    end
  end

  defp validate_plugins!(config) do
    plugins = config[:plugins] || []

    Enum.each(plugins, fn
      {module, opts} when is_atom(module) ->
        unless Code.ensure_loaded?(module) do
          raise ArgumentError,
                "GoodJob plugin module #{inspect(module)} is not available"
        end

        unless function_exported?(module, :validate, 1) do
          raise ArgumentError,
                "GoodJob plugin #{inspect(module)} must implement GoodJob.Plugin behaviour"
        end

        case module.validate(opts) do
          :ok -> :ok
          {:error, reason} -> raise ArgumentError, "Plugin #{inspect(module)} validation failed: #{reason}"
        end

      module when is_atom(module) ->
        unless Code.ensure_loaded?(module) do
          raise ArgumentError,
                "GoodJob plugin module #{inspect(module)} is not available"
        end

      invalid ->
        raise ArgumentError,
              "GoodJob plugin must be a module or {module, opts} tuple. Got: #{inspect(invalid)}"
    end)
  end

  defp validate_database_config!(config) do
    database_pool_size = config[:database_pool_size]

    if database_pool_size && (not is_integer(database_pool_size) or database_pool_size < 1) do
      raise ArgumentError,
            "GoodJob database_pool_size must be a positive integer. Got: #{inspect(database_pool_size)}"
    end

    statement_timeout = config[:database_statement_timeout]

    if statement_timeout && (not is_integer(statement_timeout) or statement_timeout < 0) do
      raise ArgumentError,
            "GoodJob database_statement_timeout must be a non-negative integer (milliseconds). Got: #{inspect(statement_timeout)}"
    end

    lock_timeout = config[:database_lock_timeout]

    if lock_timeout && (not is_integer(lock_timeout) or lock_timeout < 0) do
      raise ArgumentError,
            "GoodJob database_lock_timeout must be a non-negative integer (milliseconds). Got: #{inspect(lock_timeout)}"
    end
  end

  defp validate_notifier_config!(config) do
    notifier_pool_size = config[:notifier_pool_size]

    if notifier_pool_size && (not is_integer(notifier_pool_size) or notifier_pool_size < 1) do
      raise ArgumentError,
            "GoodJob notifier_pool_size must be a positive integer. Got: #{inspect(notifier_pool_size)}"
    end

    notifier_channel = config[:notifier_channel]

    if notifier_channel && not is_binary(notifier_channel) do
      raise ArgumentError,
            "GoodJob notifier_channel must be a string. Got: #{inspect(notifier_channel)}"
    end

    notifier_wait_interval = config[:notifier_wait_interval]

    if notifier_wait_interval && (not is_integer(notifier_wait_interval) or notifier_wait_interval < 1) do
      raise ArgumentError,
            "GoodJob notifier_wait_interval must be a positive integer (milliseconds). Got: #{inspect(notifier_wait_interval)}"
    end

    notifier_keepalive_interval = config[:notifier_keepalive_interval]

    if notifier_keepalive_interval &&
         (not is_integer(notifier_keepalive_interval) or notifier_keepalive_interval < 1) do
      raise ArgumentError,
            "GoodJob notifier_keepalive_interval must be a positive integer (milliseconds). Got: #{inspect(notifier_keepalive_interval)}"
    end
  end

  defp validate_external_jobs!(config) do
    external_jobs = config[:external_jobs]

    if external_jobs && not is_map(external_jobs) do
      raise ArgumentError,
            "GoodJob external_jobs must be a map. Got: #{inspect(external_jobs)}"
    end

    if external_jobs do
      Enum.each(external_jobs, fn {external_class, elixir_module} ->
        unless is_binary(external_class) do
          raise ArgumentError,
                "GoodJob external_jobs keys must be strings (external job class names). " <>
                  "Got key: #{inspect(external_class)}"
        end

        unless is_atom(elixir_module) do
          raise ArgumentError,
                "GoodJob external_jobs values must be atoms (Elixir module names). " <>
                  "Got value for #{inspect(external_class)}: #{inspect(elixir_module)}"
        end
      end)
    end
  end
end
