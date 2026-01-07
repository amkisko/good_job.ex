import Config

config :habit_tracker, HabitTrackerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: HabitTrackerWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: HabitTracker.PubSub,
  live_view: [signing_salt: "habit_tracker"]

config :habit_tracker, HabitTrackerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "habit_tracker_secret_key_base_for_development_only_change_in_production",
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:habit_tracker, ~w(--watch)]},
    esbuild: {Esbuild, :install_and_run, [:habit_tracker, ~w(--sourcemap=inline --watch)]}
  ]

config :habit_tracker,
  ecto_repos: [HabitTracker.Repo]

config :habit_tracker, HabitTracker.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "habit_tracker_dev",
  pool_size: 10,
  show_sensitive_data_on_connection_error: true

# GoodJob Configuration
config :good_job, :config,
  repo: HabitTracker.Repo,
  execution_mode: :async,
  max_processes: 5,
  poll_interval: 30,
  # Queue configuration examples:
  #   "*" - all queues with default concurrency
  #   "queue1:5,queue2:10" - comma-separated with concurrency
  #   "queue1:2;queue2:1;*" - semicolon-separated pools (Ruby GoodJob format)
  queues: "*",
  enable_listen_notify: true,
  enable_cron: true,
  cleanup_interval_seconds: 600,
  cleanup_interval_jobs: 1000,
  cleanup_discarded_jobs: true,
  cleanup_preserved_jobs_before_seconds_ago: 1_209_600,  # 14 days
  shutdown_timeout: 25,
  queue_select_limit: nil,  # No limit (or set to 1000+ for large queues)
  enable_pauses: false,
  advisory_lock_heartbeat: false,
  pubsub_server: HabitTracker.PubSub,
  cron: [
    daily_task_update: [
      cron: "0 0 * * *", # Every day at midnight
      class: HabitTracker.Jobs.DailyTaskUpdateJob,
      args: %{}
    ],
    streak_calculation: [
      cron: "0 1 * * *", # Every day at 1 AM
      class: HabitTracker.Jobs.StreakCalculationJob,
      args: %{}
    ],
    points_calculation: [
      cron: "0 2 * * *", # Every day at 2 AM
      class: HabitTracker.Jobs.PointsCalculationJob,
      args: %{}
    ],
    data_sync: [
      cron: "*/30 * * * *", # Every 30 minutes
      class: HabitTracker.Jobs.DataSyncJob,
      args: %{}
    ]
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  habit_tracker: [
    args: ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "4.1.12",
  habit_tracker: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure StyleCapsule to output to priv/static/assets/css (like Tailwind)
config :style_capsule,
  output_dir: "priv/static/assets/css"
