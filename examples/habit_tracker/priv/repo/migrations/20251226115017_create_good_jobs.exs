defmodule Elixir.HabitTracker.Repo.Migrations.CreateGoodJobs do
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
