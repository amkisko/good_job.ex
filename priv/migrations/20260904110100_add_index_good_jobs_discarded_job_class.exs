defmodule GoodJob.Migrations.AddIndexGoodJobsDiscardedJobClass do
  @moduledoc false

  # Ruby GoodJob 4.x update migration 15. IF NOT EXISTS keeps shared DBs safe.

  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_discarded_job_class
    ON good_jobs (job_class, finished_at)
    WHERE finished_at IS NOT NULL AND error IS NOT NULL
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS index_good_jobs_on_discarded_job_class")
  end
end
