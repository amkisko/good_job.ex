import Config

# Configure Ecto repos
# This is needed for mix ecto.* commands to work
config :good_job, ecto_repos: [GoodJob.TestRepo]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Only import if the file exists to avoid errors when dev.exs doesn't exist
env_config = Path.join(__DIR__, "#{config_env()}.exs")

if File.exists?(env_config) do
  import_config "#{config_env()}.exs"
end
