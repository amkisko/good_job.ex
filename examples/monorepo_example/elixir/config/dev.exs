import Config

# Development-specific configuration
config :logger, level: :debug

config :monorepo_example_worker, MonorepoExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true
