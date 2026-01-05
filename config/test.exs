import Config

# Get database URL from environment or use defaults
database_url =
  System.get_env("GOOD_JOB_DATABASE_URL") ||
    System.get_env("DATABASE_URL") ||
    "postgres://postgres:postgres@localhost/good_job_test"

# Parse database URL and configure repo
config_params = GoodJob.DatabaseURL.parse(database_url)

# Configure GoodJob test repository
config :good_job,
       GoodJob.TestRepo,
       Keyword.merge(config_params,
         pool: Ecto.Adapters.SQL.Sandbox,
         pool_size: 10,
         # Disable Ecto query logging in tests
         log: false
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
  # Remove console backend to suppress all logs
  config :logger,
    backends: [],
    level: :error,
    compile_time_purge_matching: [
      [level_lower_than: :error]
    ]
end
