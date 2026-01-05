defmodule GoodJob.RepoPool do
  @moduledoc """
  Database connection pool management for GoodJob.

  This module provides utilities for configuring and managing database
  connection pools for different GoodJob components:
  - Job processing (schedulers, executors)
  - LISTEN/NOTIFY (notifier)
  - Utility operations (cleanup, stats)

  ## Connection Pool Sizing

  GoodJob requires database connections for:
  1. **Job Processing**: 1 connection per scheduler process (max_processes)
  2. **LISTEN/NOTIFY**: 1 dedicated connection (separate from pool)
  3. **Utility Operations**: Shared with job processing pool

  ### Recommended Pool Sizes

  **For External Mode (separate worker process)**:
  ```elixir
  # config/prod.exs
  config :my_app, MyApp.Repo,
    pool_size: GoodJob.Config.max_processes() + 2  # +2 for utility operations (cleanup, etc.)
  ```

  **For Async Mode (same process as web server)**:
  ```elixir
  # config/dev.exs
  config :my_app, MyApp.Repo,
    pool_size: web_server_processes + GoodJob.Config.max_processes() + 2
  ```

  ## Statement and Lock Timeouts

  GoodJob can configure PostgreSQL timeouts to prevent long-running queries
  from blocking other operations:

  ```elixir
  # config/prod.exs
  config :good_job,
    database_statement_timeout: 30_000,  # 30 seconds
    database_lock_timeout: 5_000          # 5 seconds
  ```

  These timeouts are set per-connection when the pool is initialized.
  """

  @doc """
  Applies database configuration (timeouts, pool size) to a repository.

  This should be called during application startup to ensure all connections
  in the pool have the correct settings.
  """
  @spec configure_repo(Ecto.Repo.t()) :: :ok
  def configure_repo(_repo) do
    :ok
  end

  @doc """
  Calculates recommended pool size based on GoodJob configuration.

  Returns the recommended pool size for the main repository.
  """
  @spec recommended_pool_size() :: integer()
  def recommended_pool_size do
    max_processes = GoodJob.Config.max_processes()
    base_size = max_processes + 2

    case GoodJob.Config.database_pool_size() do
      nil -> base_size
      size -> max(size, base_size)
    end
  end

  @doc """
  Calculates total connections needed (including LISTEN/NOTIFY).

  This includes:
  - Job processing pool
  - LISTEN/NOTIFY connection (separate)
  - Utility operations (shared with job processing)
  """
  @spec total_connections_needed() :: integer()
  def total_connections_needed do
    recommended_pool_size() + GoodJob.Config.notifier_pool_size()
  end

  @doc """
  Returns SQL commands to set timeouts (for use in after_connect).

  Use this in your Repo configuration:

      config :my_app, MyApp.Repo,
        after_connect: {GoodJob.RepoPool, :set_timeouts}

  Or manually:

      defmodule MyApp.Repo do
        def init(_type, config) do
          config = Keyword.put(config, :after_connect, fn conn ->
            GoodJob.RepoPool.set_timeouts(conn)
          end)
          {:ok, config}
        end
      end
  """
  @type postgrex_conn :: %{__struct__: atom()}

  @spec set_timeouts(postgrex_conn()) :: :ok
  def set_timeouts(conn) do
    statement_timeout = GoodJob.Config.database_statement_timeout()
    lock_timeout = GoodJob.Config.database_lock_timeout()

    if statement_timeout do
      Postgrex.query!(conn, "SET statement_timeout = $1", [statement_timeout])
    end

    if lock_timeout do
      Postgrex.query!(conn, "SET lock_timeout = $1", [lock_timeout])
    end

    :ok
  end
end
