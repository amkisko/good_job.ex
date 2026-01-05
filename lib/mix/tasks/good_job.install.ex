defmodule Mix.Tasks.GoodJob.Install do
  @moduledoc """
  Installs GoodJob by creating the necessary database migrations.

      mix good_job.install

  This will create a migration file for the GoodJob tables.
  """

  use Mix.Task

  @shortdoc "Installs GoodJob database migrations"

  @doc false
  def run(_args) do
    # Load config files to access ecto_repos
    Mix.Task.run("loadconfig", [])

    app = Mix.Project.config()[:app]
    repo = get_repo()

    ensure_repo(repo, [])

    path = migrations_path(repo)

    # Check if migration already exists
    existing_migration = find_existing_migration(path)

    if existing_migration do
      # Check if migration has been applied
      if migration_applied?(repo, existing_migration) do
        Mix.shell().info("""
        GoodJob migration already exists and has been applied:
        #{existing_migration}

        No action needed.
        """)
      else
        Mix.shell().info("""
        GoodJob migration already exists but hasn't been applied:
        #{existing_migration}

        Run: mix ecto.migrate
        """)
      end

      :ok
    else
      # Create new migration
      file = Path.join(path, "#{timestamp()}_create_good_jobs.exs")
      create_directory(path)
      create_migration_file(file, app, repo)
    end
  end

  defp find_existing_migration(path) do
    case File.ls(path) do
      {:ok, files} ->
        files
        |> Enum.find(fn file ->
          String.contains?(file, "create_good_jobs")
        end)
        |> case do
          nil -> nil
          filename -> Path.join(path, filename)
        end

      {:error, _} ->
        nil
    end
  end

  defp migration_applied?(repo, migration_path) do
    # Extract version from filename (e.g., "20251227134037_create_good_jobs.exs" -> "20251227134037")
    version =
      migration_path
      |> Path.basename()
      |> String.split("_")
      |> List.first()

    if version do
      try do
        # Try to check if the migration is in schema_migrations
        # This requires the repo to be started and the database to be accessible
        case check_schema_migrations(repo, version) do
          true ->
            true

          false ->
            # Fallback: check if the tables exist (migration might have been applied
            # but version not recorded, or schema_migrations table doesn't exist yet)
            check_tables_exist(repo)

          # If we can't check, assume not applied
          :error ->
            false
        end
      rescue
        _ -> false
      end
    else
      false
    end
  end

  defp check_schema_migrations(repo, version) do
    # Use Ecto.Migrator.with_repo for proper repo lifecycle in Mix tasks
    case Ecto.Migrator.with_repo(repo, fn repo ->
           # Check if schema_migrations table exists and contains the version
           query = "SELECT 1 FROM schema_migrations WHERE version = $1 LIMIT 1"

           case Ecto.Adapters.SQL.query(repo, query, [version]) do
             {:ok, %{rows: [[1]]}} -> true
             {:ok, %{rows: []}} -> false
             {:error, %Postgrex.Error{postgres: %{code: :undefined_table}}} -> false
             _ -> false
           end
         end) do
      {:ok, result, _} -> result
      _ -> false
    end
  rescue
    _ -> false
  end

  defp check_tables_exist(repo) do
    # Check if the good_jobs table exists as a fallback indicator
    # that the migration has been applied
    # Use Ecto.Migrator.with_repo for proper repo lifecycle in Mix tasks
    case Ecto.Migrator.with_repo(repo, fn repo ->
           query = """
           SELECT EXISTS (
             SELECT 1
             FROM information_schema.tables
             WHERE table_schema = 'public'
             AND table_name = 'good_jobs'
           )
           """

           case Ecto.Adapters.SQL.query(repo, query, []) do
             {:ok, %{rows: [[true]]}} ->
               true

             {:ok, %{rows: [[false]]}} ->
               false

             # PostgreSQL returns 't' for true
             {:ok, %{rows: [["t"]]}} ->
               true

             # PostgreSQL returns 'f' for false
             {:ok, %{rows: [["f"]]}} ->
               false

             {:ok, %{rows: [[value]]}} when value in [true, "t", 1, "true"] ->
               true

             {:ok, %{rows: [[value]]}} when value in [false, "f", 0, "false"] ->
               false

             {:ok, %{rows: rows}} when is_list(rows) and rows != [] ->
               # Handle any truthy/falsy value
               [first_row] = rows
               [first_value] = first_row

               case first_value do
                 v when v in [true, "t", "true", 1] -> true
                 v when v in [false, "f", "false", 0, nil] -> false
                 _ -> false
               end

             {:error, _reason} ->
               # If we can't query, assume tables don't exist
               false

             _ ->
               false
           end
         end) do
      {:ok, result, _} -> result
      _ -> false
    end
  rescue
    _e ->
      # If we can't check (repo not configured, DB not accessible, etc.),
      # assume tables don't exist to be safe
      false
  end

  defp create_migration_file(file, app, repo) do
    assigns = [mod: Module.concat([repo, Migrations, CreateGoodJobs]), app: app]

    content = migration_content(assigns)

    create_file(file, content)

    Mix.shell().info("""
    GoodJob migration created at #{file}

    Now run:
        mix ecto.migrate
    """)
  end

  defp migration_content(assigns) do
    """
      defmodule #{assigns[:mod]} do
        @moduledoc false

        use Ecto.Migration

        def up do
          # Create good_jobs table
          create table(:good_jobs, primary_key: false) do
            add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
            add :queue_name, :text
            add :priority, :integer
            add :serialized_params, :jsonb
            add :scheduled_at, :utc_datetime_usec
            add :performed_at, :utc_datetime_usec
            add :finished_at, :utc_datetime_usec
            add :error, :text

            add :created_at, :utc_datetime_usec, null: false
            add :updated_at, :utc_datetime_usec, null: false

            add :active_job_id, :uuid
            add :concurrency_key, :text
            add :cron_key, :text
            add :retried_good_job_id, :uuid
            add :cron_at, :utc_datetime_usec
            add :batch_id, :uuid
            add :batch_callback_id, :uuid
            add :is_discrete, :boolean
            add :executions_count, :integer
            add :job_class, :text
            add :error_event, :smallint
            add :labels, {:array, :text}
            add :locked_by_id, :uuid
            add :locked_at, :utc_datetime_usec
          end

          # Create good_job_batches table
          create table(:good_job_batches, primary_key: false) do
            add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
            add :description, :text
            add :serialized_properties, :jsonb
            add :on_finish, :text
            add :on_success, :text
            add :on_discard, :text
            add :callback_queue_name, :text
            add :callback_priority, :integer
            add :enqueued_at, :utc_datetime_usec
            add :discarded_at, :utc_datetime_usec
            add :finished_at, :utc_datetime_usec
            add :jobs_finished_at, :utc_datetime_usec

            add :created_at, :utc_datetime_usec, null: false
            add :updated_at, :utc_datetime_usec, null: false
          end

          # Create good_job_executions table
          create table(:good_job_executions, primary_key: false) do
            add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
            add :active_job_id, :uuid, null: false
            add :job_class, :text
            add :queue_name, :text
            add :serialized_params, :jsonb
            add :scheduled_at, :utc_datetime_usec
            add :finished_at, :utc_datetime_usec
            add :error, :text
            add :error_event, :smallint
            add :error_backtrace, {:array, :text}
            add :process_id, :uuid
            add :duration, :interval

            add :created_at, :utc_datetime_usec, null: false
            add :updated_at, :utc_datetime_usec, null: false
          end

          # Create good_job_processes table
          create table(:good_job_processes, primary_key: false) do
            add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
            add :state, :jsonb
            add :lock_type, :smallint

            add :created_at, :utc_datetime_usec, null: false
            add :updated_at, :utc_datetime_usec, null: false
          end

          # Create good_job_settings table
          create table(:good_job_settings, primary_key: false) do
            add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
            add :key, :text, null: false
            add :value, :jsonb

            add :created_at, :utc_datetime_usec, null: false
            add :updated_at, :utc_datetime_usec, null: false
          end

          # Indexes for good_jobs
          create index(:good_jobs, [:scheduled_at],
            where: "finished_at IS NULL",
            name: :index_good_jobs_on_scheduled_at
          )

          create index(:good_jobs, [:queue_name, :scheduled_at],
            where: "finished_at IS NULL",
            name: :index_good_jobs_on_queue_name_and_scheduled_at
          )

          create index(:good_jobs, [:active_job_id, :created_at],
            name: :index_good_jobs_on_active_job_id_and_created_at
          )

          create index(:good_jobs, [:concurrency_key],
            where: "finished_at IS NULL",
            name: :index_good_jobs_on_concurrency_key_when_unfinished
          )

          create index(:good_jobs, [:concurrency_key, :created_at],
            name: :index_good_jobs_on_concurrency_key_and_created_at
          )

          create index(:good_jobs, [:cron_key, :created_at],
            where: "cron_key IS NOT NULL",
            name: :index_good_jobs_on_cron_key_and_created_at_cond
          )

          create index(:good_jobs, [:cron_key, :cron_at],
            where: "cron_key IS NOT NULL",
            unique: true,
            name: :index_good_jobs_on_cron_key_and_cron_at_cond
          )

          create index(:good_jobs, [:finished_at],
            where: "finished_at IS NOT NULL",
            name: :index_good_jobs_jobs_on_finished_at_only
          )

          create index(:good_jobs, [:priority, :created_at],
            where: "finished_at IS NULL",
            name: :index_good_jobs_jobs_on_priority_created_at_when_unfinished
          )

          create index(:good_jobs, [:priority, :created_at],
            where: "finished_at IS NULL",
            name: :index_good_job_jobs_for_candidate_lookup
          )

          create index(:good_jobs, [:priority, :scheduled_at],
            where: "finished_at IS NULL AND locked_by_id IS NULL",
            name: :index_good_jobs_on_priority_scheduled_at_unfinished_unlocked
          )

          create index(:good_jobs, [:batch_id],
            where: "batch_id IS NOT NULL"
          )

          create index(:good_jobs, [:batch_callback_id],
            where: "batch_callback_id IS NOT NULL"
          )

          create index(:good_jobs, [:job_class],
            name: :index_good_jobs_on_job_class
          )

          create index(:good_jobs, [:labels],
            using: :gin,
            where: "labels IS NOT NULL",
            name: :index_good_jobs_on_labels
          )

          create index(:good_jobs, [:locked_by_id],
            where: "locked_by_id IS NOT NULL",
            name: :index_good_jobs_on_locked_by_id
          )

          # Indexes for good_job_executions
          create index(:good_job_executions, [:active_job_id, :created_at],
            name: :index_good_job_executions_on_active_job_id_and_created_at
          )

          create index(:good_job_executions, [:process_id, :created_at],
            name: :index_good_job_executions_on_process_id_and_created_at
          )

          # Unique index for good_job_settings
          create unique_index(:good_job_settings, [:key])
        end

        def down do
          drop table(:good_job_settings)
          drop table(:good_job_processes)
          drop table(:good_job_executions)
          drop table(:good_job_batches)
          drop table(:good_jobs)
        end
      end
    """
  end

  defp get_repo do
    app = Mix.Project.config()[:app]

    # Try to get from application config first (after loadconfig)
    ecto_repos =
      case Application.get_env(app, :ecto_repos) do
        nil -> Mix.Project.config()[:ecto_repos]
        repos -> repos
      end

    unless ecto_repos do
      Mix.raise("""
      No Ecto repository configured.

      Add this to your config/config.exs:

          config :#{app}, ecto_repos: [#{inspect(Module.concat([app, Repo]))}]
      """)
    end

    repo = List.first(ecto_repos)

    unless repo do
      Mix.raise("""
      No Ecto repository found in ecto_repos.

      Add this to your config/config.exs:

          config :#{app}, ecto_repos: [#{inspect(Module.concat([app, Repo]))}]
      """)
    end

    repo
  end

  defp ensure_repo(repo, _args) do
    path = migrations_path(repo)

    unless File.exists?(path) do
      Mix.raise("""
      The migrations directory doesn't exist: #{path}

      Please run: mix ecto.gen.repo -r #{inspect(repo)}
      """)
    end
  end

  defp migrations_path(_repo) do
    # Use source directory, not the compiled _build directory
    # This ensures we check the actual migration files, not compiled copies
    base_path = Mix.Project.config()[:app_path] || Mix.Project.app_path()

    # If base_path points to _build, find the source directory
    if String.contains?(base_path, "_build") do
      # Find the source priv/repo/migrations directory
      source_root =
        base_path
        |> Path.split()
        |> Enum.take_while(fn part -> part != "_build" end)
        |> Path.join()

      Path.join([source_root, "priv", "repo", "migrations"])
    else
      Path.join([base_path, "priv", "repo", "migrations"])
    end
  end

  defp timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)

  defp create_directory(path) do
    File.mkdir_p!(path)
  end

  defp create_file(path, contents) do
    File.write!(path, contents)
  end
end
