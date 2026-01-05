# Require test support modules before ExUnit starts
Code.require_file("test/support/notifier_setup.exs")
Code.require_file("test/support/protocol_setup.exs")

# Require test job modules
Code.require_file("test/good_job/protocol/test_jobs.ex")

ExUnit.start()

# Configure logging based on DEBUG environment variable
debug_mode = System.get_env("DEBUG") == "1"

if debug_mode do
  Logger.configure(level: :debug)
else
  # Silence all logging in tests unless DEBUG=1
  # Remove all backends to suppress log output
  Logger.remove_backend(:console)
  Logger.configure(level: :error)

  # Ensure no backends are added
  Application.put_env(:logger, :backends, [])
end

# Configure GoodJob test repository from DATABASE_URL
database_url =
  System.get_env("GOOD_JOB_DATABASE_URL") ||
    System.get_env("DATABASE_URL") ||
    "postgres://postgres:postgres@localhost/good_job_test"

# Parse database URL and configure repo
config = GoodJob.DatabaseURL.parse(database_url)

Application.put_env(
  :good_job,
  GoodJob.TestRepo,
  Keyword.merge(config,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10,
    # Disable Ecto query logging in tests
    log: false
  )
)

# Configure GoodJob
Application.put_env(:good_job, :config, %{
  repo: GoodJob.TestRepo,
  execution_mode: :async,
  max_processes: 5,
  poll_interval: 1,
  enable_listen_notify: true
})

# Start the test repo
{:ok, _} = GoodJob.TestRepo.start_link()

# Start minimal GoodJob processes needed for testing
{:ok, _} = Registry.start_link(keys: :unique, name: GoodJob.Registry)
{:ok, _} = GoodJob.ProcessTracker.start_link([])

# Start Ecto repos for testing
Ecto.Adapters.SQL.Sandbox.mode(GoodJob.TestRepo, :manual)
