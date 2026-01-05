import Config

# Configure database from DATABASE_URL if available
if database_url = System.get_env("GOOD_JOB_DATABASE_URL") || System.get_env("DATABASE_URL") do
  GoodJob.DatabaseURL.configure_repo_from_env(MonorepoExample.Repo)
end
