import Config

# Dev config is intentionally minimal. Load benches configure TestRepo at runtime
# via Application.put_env/3 (see benchmarks/load.exs).
config :logger, level: :info
