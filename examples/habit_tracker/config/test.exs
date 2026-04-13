import Config

config :habit_tracker, HabitTrackerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  code_reloader: false

config :habit_tracker, HabitTracker.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "habit_tracker_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
