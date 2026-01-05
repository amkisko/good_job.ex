defmodule GoodJob.Config.Env do
  @moduledoc """
  Environment variable parsing and merging for GoodJob configuration.
  """

  @doc """
  Merges environment variables into configuration.
  """
  def merge_env_vars(config) do
    config
    |> maybe_put(:execution_mode, System.get_env("GOOD_JOB_EXECUTION_MODE"))
    |> maybe_put(:queues, System.get_env("GOOD_JOB_QUEUES"))
    |> maybe_put(:max_processes, System.get_env("GOOD_JOB_MAX_PROCESSES"))
    |> maybe_put(:poll_interval, System.get_env("GOOD_JOB_POLL_INTERVAL"))
    |> maybe_put(:max_cache, System.get_env("GOOD_JOB_MAX_CACHE"))
    |> maybe_put(:enable_cron, System.get_env("GOOD_JOB_ENABLE_CRON"))
    |> maybe_put(:enable_listen_notify, System.get_env("GOOD_JOB_ENABLE_LISTEN_NOTIFY"))
    |> maybe_put(:database_pool_size, System.get_env("GOOD_JOB_DATABASE_POOL_SIZE"))
    |> maybe_put(:database_statement_timeout, System.get_env("GOOD_JOB_DATABASE_STATEMENT_TIMEOUT"))
    |> maybe_put(:database_lock_timeout, System.get_env("GOOD_JOB_DATABASE_LOCK_TIMEOUT"))
    |> maybe_put(:notifier_pool_size, System.get_env("GOOD_JOB_NOTIFIER_POOL_SIZE"))
    |> maybe_put(:notifier_channel, System.get_env("GOOD_JOB_NOTIFIER_CHANNEL"))
    |> maybe_put(:notifier_wait_interval, System.get_env("GOOD_JOB_NOTIFIER_WAIT_INTERVAL"))
    |> maybe_put(:notifier_keepalive_interval, System.get_env("GOOD_JOB_NOTIFIER_KEEPALIVE_INTERVAL"))
    |> maybe_put(:queue_select_limit, System.get_env("GOOD_JOB_QUEUE_SELECT_LIMIT"))
    |> maybe_put(:cleanup_discarded_jobs, System.get_env("GOOD_JOB_CLEANUP_DISCARDED_JOBS"))
    |> maybe_put(
      :cleanup_preserved_jobs_before_seconds_ago,
      System.get_env("GOOD_JOB_CLEANUP_PRESERVED_JOBS_BEFORE_SECONDS_AGO")
    )
    |> maybe_put(:enable_pauses, System.get_env("GOOD_JOB_ENABLE_PAUSES"))
    |> maybe_put(:advisory_lock_heartbeat, System.get_env("GOOD_JOB_ADVISORY_LOCK_HEARTBEAT"))
    |> maybe_put(:cron, parse_cron_env())
  end

  defp parse_cron_env do
    case System.get_env("GOOD_JOB_CRON") do
      nil -> nil
      json -> Jason.decode!(json, keys: :atoms)
    end
  rescue
    _ -> nil
  end

  defp maybe_put(config, _key, nil), do: config
  defp maybe_put(config, _key, ""), do: config

  defp maybe_put(config, key, value) when is_binary(value) do
    case key do
      :execution_mode ->
        atom_value = String.to_existing_atom(value)
        Map.put(config, key, atom_value)

      :max_processes ->
        Map.put(config, key, String.to_integer(value))

      :poll_interval ->
        Map.put(config, key, String.to_integer(value))

      :max_cache ->
        Map.put(config, key, String.to_integer(value))

      :enable_cron ->
        Map.put(config, key, value in ["true", "1", "yes"])

      :enable_listen_notify ->
        Map.put(config, key, value in ["true", "1", "yes"])

      :database_pool_size ->
        Map.put(config, key, String.to_integer(value))

      :database_statement_timeout ->
        Map.put(config, key, String.to_integer(value))

      :database_lock_timeout ->
        Map.put(config, key, String.to_integer(value))

      :notifier_pool_size ->
        Map.put(config, key, String.to_integer(value))

      :notifier_wait_interval ->
        Map.put(config, key, String.to_integer(value))

      :notifier_keepalive_interval ->
        Map.put(config, key, String.to_integer(value))

      :queue_select_limit ->
        Map.put(config, key, String.to_integer(value))

      :cleanup_preserved_jobs_before_seconds_ago ->
        Map.put(config, key, String.to_integer(value))

      :cleanup_discarded_jobs ->
        Map.put(config, key, value in ["true", "1", "yes"])

      :enable_pauses ->
        Map.put(config, key, value in ["true", "1", "yes"])

      :advisory_lock_heartbeat ->
        Map.put(config, key, value in ["true", "1", "yes"])

      _ ->
        Map.put(config, key, value)
    end
  end

  defp maybe_put(config, _key, _value), do: config
end
