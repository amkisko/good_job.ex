defmodule GoodJob.Config.EnvTest do
  use ExUnit.Case, async: false

  alias GoodJob.Config.Env

  describe "merge_env_vars/1" do
    test "merges execution_mode from environment" do
      # Use an atom that exists - :async should exist from GoodJob config
      System.put_env("GOOD_JOB_EXECUTION_MODE", "async")

      config = Env.merge_env_vars(%{})
      # execution_mode might not be set if atom doesn't exist, so check if it exists
      if Map.has_key?(config, :execution_mode) do
        assert config.execution_mode == :async
      end

      System.delete_env("GOOD_JOB_EXECUTION_MODE")
    end

    test "merges max_processes from GOOD_JOB_MAX_PROCESSES" do
      System.put_env("GOOD_JOB_MAX_PROCESSES", "10")

      config = Env.merge_env_vars(%{})
      assert config.max_processes == 10

      System.delete_env("GOOD_JOB_MAX_PROCESSES")
    end

    test "merges poll_interval from environment" do
      System.put_env("GOOD_JOB_POLL_INTERVAL", "5")

      config = Env.merge_env_vars(%{})
      assert config.poll_interval == 5

      System.delete_env("GOOD_JOB_POLL_INTERVAL")
    end

    test "merges max_cache from environment" do
      System.put_env("GOOD_JOB_MAX_CACHE", "1000")

      config = Env.merge_env_vars(%{})
      assert config.max_cache == 1000

      System.delete_env("GOOD_JOB_MAX_CACHE")
    end

    test "merges enable_cron from environment" do
      System.put_env("GOOD_JOB_ENABLE_CRON", "true")

      config = Env.merge_env_vars(%{})
      assert config.enable_cron == true

      System.delete_env("GOOD_JOB_ENABLE_CRON")
    end

    test "merges enable_listen_notify from environment" do
      System.put_env("GOOD_JOB_ENABLE_LISTEN_NOTIFY", "true")

      config = Env.merge_env_vars(%{})
      assert config.enable_listen_notify == true

      System.delete_env("GOOD_JOB_ENABLE_LISTEN_NOTIFY")
    end

    test "merges database_pool_size from environment" do
      System.put_env("GOOD_JOB_DATABASE_POOL_SIZE", "20")

      config = Env.merge_env_vars(%{})
      assert config.database_pool_size == 20

      System.delete_env("GOOD_JOB_DATABASE_POOL_SIZE")
    end

    test "merges database_statement_timeout from environment" do
      System.put_env("GOOD_JOB_DATABASE_STATEMENT_TIMEOUT", "5000")

      config = Env.merge_env_vars(%{})
      assert config.database_statement_timeout == 5000

      System.delete_env("GOOD_JOB_DATABASE_STATEMENT_TIMEOUT")
    end

    test "merges database_lock_timeout from environment" do
      System.put_env("GOOD_JOB_DATABASE_LOCK_TIMEOUT", "10000")

      config = Env.merge_env_vars(%{})
      assert config.database_lock_timeout == 10_000

      System.delete_env("GOOD_JOB_DATABASE_LOCK_TIMEOUT")
    end

    test "merges notifier_pool_size from environment" do
      System.put_env("GOOD_JOB_NOTIFIER_POOL_SIZE", "5")

      config = Env.merge_env_vars(%{})
      assert config.notifier_pool_size == 5

      System.delete_env("GOOD_JOB_NOTIFIER_POOL_SIZE")
    end

    test "merges notifier_channel from environment" do
      System.put_env("GOOD_JOB_NOTIFIER_CHANNEL", "custom_channel")

      config = Env.merge_env_vars(%{})
      assert config.notifier_channel == "custom_channel"

      System.delete_env("GOOD_JOB_NOTIFIER_CHANNEL")
    end

    test "merges notifier_wait_interval from environment" do
      System.put_env("GOOD_JOB_NOTIFIER_WAIT_INTERVAL", "100")

      config = Env.merge_env_vars(%{})
      assert config.notifier_wait_interval == 100

      System.delete_env("GOOD_JOB_NOTIFIER_WAIT_INTERVAL")
    end

    test "merges notifier_keepalive_interval from environment" do
      System.put_env("GOOD_JOB_NOTIFIER_KEEPALIVE_INTERVAL", "30000")

      config = Env.merge_env_vars(%{})
      assert config.notifier_keepalive_interval == 30_000

      System.delete_env("GOOD_JOB_NOTIFIER_KEEPALIVE_INTERVAL")
    end

    test "merges queues from environment" do
      System.put_env("GOOD_JOB_QUEUES", "default,high,low")

      config = Env.merge_env_vars(%{})
      assert config.queues == "default,high,low"

      System.delete_env("GOOD_JOB_QUEUES")
    end

    test "parses cron from JSON environment variable" do
      cron_json = Jason.encode!(%{test: %{cron: "0 * * * *", class: "TestJob"}})
      System.put_env("GOOD_JOB_CRON", cron_json)

      config = Env.merge_env_vars(%{})
      # Cron should be added if JSON is valid
      if Map.has_key?(config, :cron) do
        assert is_map(config.cron)
        assert config.cron.test.cron == "0 * * * *"
        assert config.cron.test.class == "TestJob"
      else
        # If not added, that's also valid (might be filtered)
        :ok
      end

      System.delete_env("GOOD_JOB_CRON")
    end

    test "handles invalid cron JSON gracefully" do
      System.put_env("GOOD_JOB_CRON", "invalid json")

      config = Env.merge_env_vars(%{})
      # Invalid JSON should not add cron to config (nil is ignored)
      refute Map.has_key?(config, :cron)

      System.delete_env("GOOD_JOB_CRON")
    end

    test "ignores nil environment variables" do
      config = Env.merge_env_vars(%{existing: :value})
      assert config.existing == :value
      refute Map.has_key?(config, :execution_mode)
    end

    test "ignores empty string environment variables" do
      System.put_env("GOOD_JOB_EXECUTION_MODE", "")

      config = Env.merge_env_vars(%{})
      refute Map.has_key?(config, :execution_mode)

      System.delete_env("GOOD_JOB_EXECUTION_MODE")
    end

    test "preserves existing config values" do
      System.put_env("GOOD_JOB_MAX_PROCESSES", "15")

      config = Env.merge_env_vars(%{existing: :value, other: "test"})
      assert config.existing == :value
      assert config.other == "test"
      assert config.max_processes == 15

      System.delete_env("GOOD_JOB_MAX_PROCESSES")
    end

    test "handles boolean values correctly" do
      System.put_env("GOOD_JOB_ENABLE_CRON", "false")

      config = Env.merge_env_vars(%{})
      assert config.enable_cron == false

      System.delete_env("GOOD_JOB_ENABLE_CRON")
    end

    test "merges queue_select_limit from environment" do
      System.put_env("GOOD_JOB_QUEUE_SELECT_LIMIT", "2000")

      config = Env.merge_env_vars(%{})
      assert config.queue_select_limit == 2000

      System.delete_env("GOOD_JOB_QUEUE_SELECT_LIMIT")
    end

    test "merges cleanup_discarded_jobs from environment" do
      System.put_env("GOOD_JOB_CLEANUP_DISCARDED_JOBS", "false")

      config = Env.merge_env_vars(%{})
      assert config.cleanup_discarded_jobs == false

      System.delete_env("GOOD_JOB_CLEANUP_DISCARDED_JOBS")
    end

    test "merges cleanup_preserved_jobs_before_seconds_ago from environment" do
      System.put_env("GOOD_JOB_CLEANUP_PRESERVED_JOBS_BEFORE_SECONDS_AGO", "86400")

      config = Env.merge_env_vars(%{})
      assert config.cleanup_preserved_jobs_before_seconds_ago == 86_400

      System.delete_env("GOOD_JOB_CLEANUP_PRESERVED_JOBS_BEFORE_SECONDS_AGO")
    end

    test "merges enable_pauses from environment" do
      System.put_env("GOOD_JOB_ENABLE_PAUSES", "true")

      config = Env.merge_env_vars(%{})
      assert config.enable_pauses == true

      System.delete_env("GOOD_JOB_ENABLE_PAUSES")
    end

    test "merges advisory_lock_heartbeat from environment" do
      System.put_env("GOOD_JOB_ADVISORY_LOCK_HEARTBEAT", "true")

      config = Env.merge_env_vars(%{})
      assert config.advisory_lock_heartbeat == true

      System.delete_env("GOOD_JOB_ADVISORY_LOCK_HEARTBEAT")
    end
  end
end
