# Require test support modules before ExUnit starts
Code.require_file("test/support/notifier_setup_helper.exs")
Code.require_file("test/support/protocol_setup_helper.exs")

# Require test job modules
Code.require_file("test/good_job/protocol/test_jobs_helper.exs")

ExUnit.start()

# Configure logging based on DEBUG environment variable
debug_mode = System.get_env("DEBUG") == "1"

if debug_mode do
  Logger.configure(level: :debug)
else
  # Silence all logging in tests unless DEBUG=1
  Logger.configure(level: :error)
end

# Configure GoodJob test repository.
# Prefer explicit URLs, otherwise use libpq-style PG* environment defaults.
database_url = System.get_env("GOOD_JOB_DATABASE_URL") || System.get_env("DATABASE_URL")

config =
  if is_binary(database_url) and database_url != "" do
    GoodJob.DatabaseURL.parse(database_url)
  else
    pg_host = System.get_env("PGHOST")
    pg_port = System.get_env("PGPORT")
    pg_user = System.get_env("PGUSER") || System.get_env("USER")
    pg_password = System.get_env("PGPASSWORD")
    pg_database = System.get_env("PGDATABASE") || "good_job_test"

    base = [
      username: pg_user,
      password: pg_password,
      database: pg_database,
      adapter: Ecto.Adapters.Postgres
    ]

    cond do
      is_binary(pg_host) and String.starts_with?(pg_host, "/") ->
        Keyword.merge(base, socket_dir: pg_host, port: if(pg_port, do: String.to_integer(pg_port), else: nil))

      true ->
        Keyword.merge(base,
          hostname: pg_host,
          port: if(pg_port, do: String.to_integer(pg_port), else: nil)
        )
    end
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

Application.put_env(
  :good_job,
  GoodJob.TestRepo,
  Keyword.merge(config,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 30,
    queue_target: 10_000,
    queue_interval: 10_000,
    # Disable Ecto query logging in tests
    log: false
  )
)

# Configure GoodJob
Application.put_env(:good_job, :config, %{
  repo: GoodJob.TestRepo,
  execution_mode: :async,
  max_processes: 5,
  poll_interval: 1,
  enable_listen_notify: true
})

# Start the test repo (handle already started case)
case GoodJob.TestRepo.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
  {:error, reason} -> raise "Failed to start GoodJob.TestRepo in test_helper: #{inspect(reason)}"
end

# Ensure optional PostgreSQL functions used by advisory lock hash strategies are available.
# `pgcrypto` provides digest() for sha* algorithms and `uuid-ossp` provides uuid_generate_v5().
for extension <- ["pgcrypto", "\"uuid-ossp\""] do
  _ = GoodJob.TestRepo.query("CREATE EXTENSION IF NOT EXISTS #{extension}")
end

# Start minimal GoodJob processes needed for testing
case Registry.start_link(keys: :unique, name: GoodJob.Registry) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

case GoodJob.ProcessTracker.start_link([]) do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

# Start Ecto repos for testing
Ecto.Adapters.SQL.Sandbox.mode(GoodJob.TestRepo, :manual)
