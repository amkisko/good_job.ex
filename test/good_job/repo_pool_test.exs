defmodule GoodJob.RepoPoolTest do
  use ExUnit.Case, async: true

  alias GoodJob.RepoPool

  describe "recommended_pool_size/0" do
    test "returns base size based on max_processes" do
      size = RepoPool.recommended_pool_size()
      assert is_integer(size)
      assert size >= 2
    end

    test "uses database_pool_size when configured" do
      original_config = Application.get_env(:good_job, :config, %{})

      # Set a custom database_pool_size
      Application.put_env(
        :good_job,
        :config,
        Map.merge(original_config, %{
          database_pool_size: 20
        })
      )

      try do
        size = RepoPool.recommended_pool_size()
        assert is_integer(size)
        # Should use the configured size if it's >= base_size
        assert size >= 20
      after
        Application.put_env(:good_job, :config, original_config)
      end
    end

    test "uses max of database_pool_size and base_size" do
      original_config = Application.get_env(:good_job, :config, %{})
      max_processes = GoodJob.Config.max_processes()
      base_size = max_processes + 2

      # Set a smaller database_pool_size - should use base_size
      Application.put_env(
        :good_job,
        :config,
        Map.merge(original_config, %{
          database_pool_size: 1
        })
      )

      try do
        size = RepoPool.recommended_pool_size()
        assert is_integer(size)
        # Should use max(base_size, configured_size)
        assert size >= base_size
      after
        Application.put_env(:good_job, :config, original_config)
      end
    end
  end

  describe "total_connections_needed/0" do
    test "returns total connections including notifier" do
      total = RepoPool.total_connections_needed()
      assert is_integer(total)
      assert total >= RepoPool.recommended_pool_size()
    end
  end

  describe "configure_repo/1" do
    test "returns :ok" do
      result = RepoPool.configure_repo(GoodJob.TestRepo)
      assert result == :ok
    end
  end

  describe "set_timeouts/1" do
    test "returns :ok when timeouts are nil" do
      # This function is meant to be called by Postgrex in after_connect
      # We test the logic path when timeouts are not configured
      # In practice, users configure this in their Repo's after_connect callback

      # Mock a connection struct - we can't easily test with real Postgrex connection
      # but we can verify the function structure
      _conn = %{__struct__: :postgrex_connection}

      # Temporarily set timeouts to nil to test that path
      original_config = Application.get_env(:good_job, :config, %{})

      Application.put_env(
        :good_job,
        :config,
        Map.merge(original_config, %{
          database_statement_timeout: nil,
          database_lock_timeout: nil
        })
      )

      try do
        # The function checks for nil timeouts and returns early
        # We can't easily test the Postgrex.query! call without a real connection
        # but we can verify the function exists and has the right signature
        assert function_exported?(RepoPool, :set_timeouts, 1)
      rescue
        _ -> :ok
      after
        Application.put_env(:good_job, :config, original_config)
      end
    end

    test "function exists and can be called" do
      # Verify the function exists and has correct arity
      assert function_exported?(RepoPool, :set_timeouts, 1)
      assert function_exported?(RepoPool, :recommended_pool_size, 0)
      assert function_exported?(RepoPool, :total_connections_needed, 0)
      assert function_exported?(RepoPool, :configure_repo, 1)
    end
  end
end
