defmodule GoodJob.RepoPoolTest do
  use ExUnit.Case

  alias GoodJob.RepoPool
  alias GoodJob.Repo

  setup do
    original_config = Application.get_env(:good_job, :config, %{})

    on_exit(fn ->
      Application.put_env(:good_job, :config, original_config)
    end)

    Application.put_env(:good_job, :config, Map.put(original_config, :repo, GoodJob.TestRepo))

    :ok
  end

  test "recommended_pool_size uses max_processes and database_pool_size" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, max_processes: 3})
    assert RepoPool.recommended_pool_size() == 5

    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, max_processes: 3, database_pool_size: 10})
    assert RepoPool.recommended_pool_size() == 10
  end

  test "total_connections_needed accounts for notifier pool size" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, max_processes: 2, notifier_pool_size: 2})
    assert RepoPool.total_connections_needed() == 6
  end

  test "set_timeouts applies configured statement and lock timeouts" do
    Application.put_env(:good_job, :config, %{
      repo: GoodJob.TestRepo,
      database_statement_timeout: 1_000,
      database_lock_timeout: 500
    })

    repo = Repo.repo()
    conn_opts =
      repo.config()
      |> Keyword.take([:hostname, :username, :password, :database, :port, :ssl, :ssl_opts, :socket_dir])
      |> Enum.reject(fn {_, value} -> is_nil(value) end)

    {:ok, conn} = Postgrex.start_link(conn_opts)
    on_exit(fn ->
      if Process.alive?(conn) do
        GenServer.stop(conn)
      end
    end)

    assert :ok == RepoPool.set_timeouts(conn)
  end
end
