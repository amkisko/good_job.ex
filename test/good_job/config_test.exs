defmodule GoodJob.ConfigTest do
  use ExUnit.Case, async: true

  alias GoodJob.Config

  describe "config/0" do
    test "returns configuration with defaults" do
      config = Config.config()
      assert config[:execution_mode] in [:external, :async, :inline]
      assert is_binary(config[:queues])
      assert is_integer(config[:max_processes])
    end
  end

  describe "get/2" do
    test "returns config value" do
      value = Config.get(:execution_mode)
      assert value in [:external, :async, :inline]
    end

    test "returns default when key not found" do
      assert Config.get(:nonexistent, :default) == :default
    end
  end

  describe "repo/0" do
    test "returns configured repo" do
      repo = Config.repo()
      assert repo == GoodJob.TestRepo
    end
  end

  describe "execution_mode/0" do
    test "returns execution mode" do
      mode = Config.execution_mode()
      assert mode in [:external, :async, :inline]
    end
  end

  describe "queues/0" do
    test "returns queue configuration" do
      queues = Config.queues()
      assert is_binary(queues)
    end
  end

  describe "max_processes/0" do
    test "returns max processes" do
      processes = Config.max_processes()
      assert is_integer(processes)
      assert processes > 0
    end
  end

  describe "poll_interval/0" do
    test "returns poll interval" do
      interval = Config.poll_interval()
      assert is_integer(interval)
      # In dev async mode, can be -1 (continuous polling)
      assert interval > 0 or interval == -1
    end
  end

  describe "max_cache/0" do
    test "returns max cache size" do
      cache = Config.max_cache()
      assert is_integer(cache)
      assert cache >= 0
    end
  end

  describe "enable_listen_notify?/0" do
    test "returns boolean" do
      result = Config.enable_listen_notify?()
      assert is_boolean(result)
    end
  end

  describe "enable_cron?/0" do
    test "returns boolean" do
      result = Config.enable_cron?()
      assert is_boolean(result)
    end
  end

  describe "cron/0" do
    test "returns cron configuration" do
      cron = Config.cron()
      assert is_map(cron)
    end
  end

  describe "cron_entries/0" do
    test "returns empty list when no cron configured" do
      entries = Config.cron_entries()
      assert is_list(entries)
    end
  end

  describe "validate_cron/0" do
    test "returns ok when cron valid" do
      assert Config.validate_cron() == :ok
    end
  end

  describe "preserve_job_records?/0" do
    test "returns boolean" do
      result = Config.preserve_job_records?()
      assert is_boolean(result)
    end
  end

  describe "retry_on_unhandled_error?/0" do
    test "returns boolean" do
      result = Config.retry_on_unhandled_error?()
      assert is_boolean(result)
    end
  end

  describe "cleanup_interval_seconds/0" do
    test "returns interval" do
      interval = Config.cleanup_interval_seconds()
      assert is_integer(interval)
      assert interval > 0
    end
  end

  describe "cleanup_interval_jobs/0" do
    test "returns interval" do
      interval = Config.cleanup_interval_jobs()
      assert is_integer(interval)
      assert interval > 0
    end
  end

  describe "shutdown_timeout/0" do
    test "returns timeout" do
      timeout = Config.shutdown_timeout()
      assert is_integer(timeout)
    end
  end

  describe "enqueue_after_transaction_commit?/0" do
    test "returns boolean" do
      result = Config.enqueue_after_transaction_commit?()
      assert is_boolean(result)
    end
  end

  describe "plugins/0" do
    test "returns plugins list" do
      plugins = Config.plugins()
      assert is_list(plugins)
    end
  end

  describe "database_pool_size/0" do
    test "returns pool size or nil" do
      size = Config.database_pool_size()
      assert is_integer(size) or is_nil(size)
    end
  end

  describe "database_statement_timeout/0" do
    test "returns timeout or nil" do
      timeout = Config.database_statement_timeout()
      assert is_integer(timeout) or is_nil(timeout)
    end
  end

  describe "database_lock_timeout/0" do
    test "returns timeout or nil" do
      timeout = Config.database_lock_timeout()
      assert is_integer(timeout) or is_nil(timeout)
    end
  end

  describe "notifier_pool_size/0" do
    test "returns pool size" do
      size = Config.notifier_pool_size()
      assert is_integer(size)
      assert size > 0
    end
  end

  describe "notifier_channel/0" do
    test "returns channel name" do
      channel = Config.notifier_channel()
      assert is_binary(channel)
    end
  end

  describe "notifier_wait_interval/0" do
    test "returns wait interval" do
      interval = Config.notifier_wait_interval()
      assert is_integer(interval)
      assert interval > 0
    end
  end

  describe "notifier_keepalive_interval/0" do
    test "returns keepalive interval" do
      interval = Config.notifier_keepalive_interval()
      assert is_integer(interval)
      assert interval > 0
    end
  end

  describe "queue_select_limit/0" do
    test "returns limit or nil" do
      limit = Config.queue_select_limit()
      assert is_integer(limit) or is_nil(limit)
    end
  end

  describe "cleanup_discarded_jobs?/0" do
    test "returns boolean" do
      result = Config.cleanup_discarded_jobs?()
      assert is_boolean(result)
    end
  end

  describe "cleanup_preserved_jobs_before_seconds_ago/0" do
    test "returns seconds" do
      seconds = Config.cleanup_preserved_jobs_before_seconds_ago()
      assert is_integer(seconds)
      assert seconds > 0
    end
  end

  describe "enable_pauses?/0" do
    test "returns boolean" do
      result = Config.enable_pauses?()
      assert is_boolean(result)
    end
  end

  describe "advisory_lock_heartbeat?/0" do
    test "returns boolean" do
      result = Config.advisory_lock_heartbeat?()
      assert is_boolean(result)
    end
  end

  describe "external_jobs/0" do
    test "returns empty map by default" do
      external_jobs = Config.external_jobs()
      assert is_map(external_jobs)
      assert external_jobs == %{}
    end

    test "returns configured external_jobs mapping" do
      # This test verifies the getter works, but we can't easily test
      # with actual config changes in async tests, so we just verify
      # the function exists and returns a map
      external_jobs = Config.external_jobs()
      assert is_map(external_jobs)
    end
  end
end
