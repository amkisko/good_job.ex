import Config

# Configure Ecto repos
config :monorepo_example_worker, ecto_repos: [MonorepoExample.Repo]

# Configure the database
# IMPORTANT: This must match the Rails database name in config/database.yml
# Both Rails and Elixir share the same PostgreSQL database
config :monorepo_example_worker, MonorepoExample.Repo,
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASSWORD") || "postgres",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  port: String.to_integer(System.get_env("DATABASE_PORT") || "5432"),
  # Same database name as Rails: monorepo_example_development
  database: System.get_env("DATABASE_NAME") || "monorepo_example_development",
  pool_size: 10

# Configure GoodJob
config :good_job,
  config: [
    repo: MonorepoExample.Repo,
    execution_mode: :external,
    queues: "ex.default",
    max_processes: 5,
    # With LISTEN/NOTIFY enabled, polling is just a fallback safety net
    # Recommended 30+ seconds when LISTEN/NOTIFY is enabled
    poll_interval: 30,
    enable_listen_notify: true,
    enable_cron: true,
    queue_select_limit: 1_000,  # Recommended for large queues
    cleanup_discarded_jobs: true,
    cleanup_preserved_jobs_before_seconds_ago: 1_209_600,  # 14 days
    enable_pauses: false,
    advisory_lock_heartbeat: false,
    # Map external job class names to Elixir modules
    # This is the recommended approach for cross-language job processing
    # When enqueueing from Elixir, the reverse lookup is used automatically
    external_jobs: %{
      "ElixirProcessedJob" => MonorepoExample.Jobs.ProcessJob,
      "ExampleJob" => MonorepoExample.Jobs.ExampleRubyJob,
      "ScheduledRubyJob" => MonorepoExample.Jobs.ScheduledRubyJob
    },
    cron: %{
      # Elixir cron job - runs every 3 minutes
      # Note: Using different key name to avoid conflicts with Rails cron
      elixir_scheduled_from_elixir: %{
        cron: "*/3 * * * *", # Every 3 minutes
        class: MonorepoExample.Jobs.ScheduledElixirJob,
        args: %{message: "Scheduled from Elixir cron"},
        queue: "ex.default"
      },
      # Ruby cron job - runs every 5 minutes (processed by Ruby worker)
      # Note: Using different key name to avoid conflicts with Rails cron
      ruby_scheduled_from_elixir: %{
        cron: "*/5 * * * *", # Every 5 minutes
        class: MonorepoExample.Jobs.ScheduledRubyJob,
        args: %{message: "Scheduled from Elixir cron for Ruby"},
        queue: "rb.default"
      }
    }
  ]

# Phoenix configuration
config :monorepo_example_worker, MonorepoExampleWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "monorepo_example_secret_key_base_for_development_only_change_in_production",
  pubsub_server: MonorepoExample.PubSub,
  live_view: [signing_salt: "monorepo_example"]

config :phoenix, :json_library, Jason

# Configure Tailwind CSS
config :tailwind,
  version: "4.1.12",
  monorepo_example_worker: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]
