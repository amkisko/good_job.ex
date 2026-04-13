import Config

# Test-specific configuration
config :monorepo_example_worker, MonorepoExampleWeb.Endpoint,
  server: false,
  code_reloader: false

config :monorepo_example_worker, MonorepoExample.Repo,
  database: "monorepo_example_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warning
