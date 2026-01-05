import Config

# Test-specific configuration
config :monorepo_example_worker, MonorepoExample.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :logger, level: :warn
