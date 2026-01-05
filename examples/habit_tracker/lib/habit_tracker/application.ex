defmodule HabitTracker.Application do
  @moduledoc false
  use Application

  import Ecto.Query

  @impl true
  def start(_type, _args) do
    # Start GoodJob.Supervisor if execution_mode requires it
    # For :async mode, we need to start it here because GoodJob.Application
    # starts before the repo is available, so it can't detect the repo
    good_job_children =
      if GoodJob.Config.start_in_application?() do
        [GoodJob.Supervisor]
      else
        []
      end

    children =
      [
        # Start the Ecto repository
        HabitTracker.Repo
      ] ++ good_job_children ++
        [
          # Start Telemetry
          HabitTrackerWeb.Telemetry,
          # Start the PubSub system
          {Phoenix.PubSub, name: HabitTracker.PubSub},
          # Start the Endpoint (http/https)
          HabitTrackerWeb.Endpoint
        ]

    opts = [strategy: :one_for_one, name: HabitTracker.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Run seeds after the repo is started
        ensure_seeds()
        {:ok, pid}
      error ->
        error
    end
  end

  defp ensure_seeds do
    # Check if habits exist, if not, run seeds
    # Use Task.start to run in background and avoid blocking startup
    Task.start(fn ->
      # Wait a bit for the repo and GoodJob to be fully ready
      Process.sleep(1000)

      try do
        # Check if habits table exists and has data
        habit_count =
          try do
            HabitTracker.Repo.one(
              from h in HabitTracker.Schemas.Habit, select: count(h.id)
            )
          rescue
            # Table doesn't exist yet, need to run migrations
            _e in Ecto.QueryError ->
              IO.puts("⚠️  Database tables not found. Please run 'mix ecto.migrate' first.")
              :error

            e ->
              IO.puts("⚠️  Error checking habits: #{inspect(e)}")
              :error
          end

        case habit_count do
          :error ->
            :ok

          0 ->
            # No habits, run seeds by executing the seed file code directly
            seeds_path = Path.join([File.cwd!(), "priv", "repo", "seeds.exs"])

            if File.exists?(seeds_path) do
              # Read and evaluate the seed file
              seed_code = File.read!(seeds_path)
              Code.eval_string(seed_code, [], file: seeds_path)
              IO.puts("✅ Database seeded successfully on startup!")
            else
              IO.puts("⚠️  Seed file not found at #{seeds_path}")
              IO.puts("   Run 'mix run priv/repo/seeds.exs' manually to seed the database.")
            end

          count when is_integer(count) ->
            IO.puts("ℹ️  Database already has #{count} habit(s), skipping seed.")
        end
      rescue
        e ->
          IO.puts("⚠️  Could not seed database: #{inspect(e)}")
          IO.puts("   Run 'mix run priv/repo/seeds.exs' manually to seed the database.")
      end
    end)
  end
end
