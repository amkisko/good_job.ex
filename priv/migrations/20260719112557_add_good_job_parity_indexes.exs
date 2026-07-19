defmodule GoodJob.Migrations.AddGoodJobParityIndexes do
  @moduledoc false

  # Indexes present in Ruby GoodJob 4.x update migrations (08–14) that were
  # missing from the Elixir create migration. IF NOT EXISTS keeps shared DBs safe.

  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_for_candidate_dequeue_unlocked
    ON good_jobs (priority ASC NULLS LAST, scheduled_at ASC, id ASC)
    WHERE finished_at IS NULL AND locked_by_id IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_priority_scheduled_at_unfinished
    ON good_jobs (priority ASC, scheduled_at ASC, id ASC)
    WHERE finished_at IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_queue_name_priority_scheduled_at_unfinished
    ON good_jobs (queue_name ASC, scheduled_at ASC, id ASC)
    WHERE finished_at IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_queue_name
    ON good_jobs (queue_name)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_created_at
    ON good_jobs (created_at)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_discarded
    ON good_jobs (finished_at DESC)
    WHERE finished_at IS NOT NULL AND error IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_scheduled_at_and_queue_name
    ON good_jobs (scheduled_at, queue_name)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_unfinished_or_errored
    ON good_jobs (id)
    WHERE finished_at IS NULL OR error IS NOT NULL
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS index_good_jobs_for_candidate_dequeue_unlocked")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_priority_scheduled_at_unfinished")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_queue_name_priority_scheduled_at_unfinished")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_queue_name")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_created_at")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_discarded")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_scheduled_at_and_queue_name")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_unfinished_or_errored")
  end
end
