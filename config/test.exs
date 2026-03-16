import Config

# Prefer explicit URLs, then fall back to libpq-style environment defaults.
database_url = System.get_env("GOOD_JOB_DATABASE_URL") || System.get_env("DATABASE_URL")

config_params =
  if is_binary(database_url) and database_url != "" do
    # Parse database URL manually (can't use GoodJob.DatabaseURL.parse at compile time)
    uri = URI.parse(database_url)

    database =
      case uri.path do
        "/" <> db -> db
        path when is_binary(path) -> String.trim_leading(path, "/")
        _ -> nil
      end

    {username, password} =
      case uri.userinfo do
        nil ->
          {nil, nil}

        userinfo ->
          case String.split(userinfo, ":", parts: 2) do
            [user, pass] -> {user, pass}
            [user] -> {user, nil}
            _ -> {nil, nil}
          end
      end

    [
      username: username,
      password: password,
      hostname: uri.host,
      port: uri.port,
      database: database,
      adapter: Ecto.Adapters.Postgres
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
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

# Configure Ecto repos
config :good_job, ecto_repos: [GoodJob.TestRepo]

# Configure GoodJob test repository
config :good_job,
       GoodJob.TestRepo,
       Keyword.merge(config_params,
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: 30,
         queue_target: 10_000,
         queue_interval: 10_000,
         # Disable Ecto query logging in tests
         log: false,
         # Tell Ecto where to find migrations
         priv: "priv"
       )

# Configure GoodJob
config :good_job,
  config: %{
    repo: GoodJob.TestRepo,
    execution_mode: :async,
    max_processes: 5,
    poll_interval: 1,
    enable_listen_notify: true
  }

# Logger configuration - silence all logs in tests unless DEBUG=1
debug_mode = System.get_env("DEBUG") == "1"

if debug_mode do
  config :logger,
    level: :debug,
    compile_time_purge_matching: [
      [level_lower_than: :debug]
    ]
else
  config :logger, :default_handler, false

  config :logger,
    level: :error,
    compile_time_purge_matching: [
      [level_lower_than: :error]
    ]
end
