import Config

config :habit_tracker, HabitTrackerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "habit_tracker_secret_key_base_for_development_only_change_in_production",
  watchers: [
    tailwind: {Tailwind, :install_and_run, [:habit_tracker, ~w(--watch)]}
  ]

config :logger, :console, format: "[$level] $message\n"
config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
