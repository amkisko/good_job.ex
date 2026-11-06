defmodule GoodJob.Migrations.AddGoodJobRuby424SchemaParity do
  @moduledoc false

  # Ruby GoodJob update migrations 16–22 (tag v4.24.1). IF NOT EXISTS / IF EXISTS
  # keep shared databases that already applied Ruby updates safe.

  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_dequeue_by_queue
    ON good_jobs (queue_name, priority ASC NULLS LAST, created_at ASC)
    WHERE finished_at IS NULL AND locked_by_id IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_dequeue_by_queue_scheduled_at
    ON good_jobs (queue_name, priority ASC NULLS LAST, scheduled_at ASC)
    WHERE finished_at IS NULL AND locked_by_id IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_job_executions_on_scheduled_at
    ON good_job_executions (scheduled_at)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_job_batches_on_finished_at
    ON good_job_batches (finished_at)
    WHERE finished_at IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_job_batches_on_created_at_and_id
    ON good_job_batches (created_at DESC, id DESC)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_batch_id_unfinished
    ON good_jobs (batch_id)
    WHERE batch_id IS NOT NULL AND finished_at IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_batch_callback_id_unfinished
    ON good_jobs (batch_callback_id)
    WHERE batch_callback_id IS NOT NULL AND finished_at IS NULL
    """)

    execute("DROP INDEX IF EXISTS index_good_jobs_jobs_on_priority_created_at_when_unfinished")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_priority_scheduled_at_unfinished_unlocked")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_queue_name_and_scheduled_at")

    reorder_cron_index()

    execute("""
    CREATE TABLE IF NOT EXISTS good_job_concurrency_claims (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      created_at timestamp(6) without time zone NOT NULL,
      updated_at timestamp(6) without time zone NOT NULL,
      job_id uuid NOT NULL,
      locked_by_id uuid,
      state smallint NOT NULL,
      key text NOT NULL
    )
    """)

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS good_job_concurrency_claims_key_job_id_index
    ON good_job_concurrency_claims (key, job_id)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_job_concurrency_claims_for_promotion
    ON good_job_concurrency_claims (key, state, created_at)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS good_job_concurrency_claims_job_id_index
    ON good_job_concurrency_claims (job_id)
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS good_job_concurrency_claims_locked_by_id_index
    ON good_job_concurrency_claims (locked_by_id)
    WHERE locked_by_id IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_job_executions_on_created_at
    ON good_job_executions (created_at)
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS index_good_job_executions_on_created_at")
    execute("DROP INDEX IF EXISTS good_job_concurrency_claims_locked_by_id_index")
    execute("DROP INDEX IF EXISTS good_job_concurrency_claims_job_id_index")
    execute("DROP INDEX IF EXISTS index_good_job_concurrency_claims_for_promotion")
    execute("DROP INDEX IF EXISTS good_job_concurrency_claims_key_job_id_index")
    execute("DROP TABLE IF EXISTS good_job_concurrency_claims")

    execute("""
    CREATE UNIQUE INDEX IF NOT EXISTS index_good_jobs_on_cron_key_and_cron_at_cond
    ON good_jobs (cron_key, cron_at)
    WHERE cron_key IS NOT NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_queue_name_and_scheduled_at
    ON good_jobs (queue_name, scheduled_at)
    WHERE finished_at IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_on_priority_scheduled_at_unfinished_unlocked
    ON good_jobs (priority ASC NULLS LAST, scheduled_at ASC NULLS LAST)
    WHERE finished_at IS NULL AND locked_by_id IS NULL
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS index_good_jobs_jobs_on_priority_created_at_when_unfinished
    ON good_jobs (priority DESC NULLS LAST, created_at ASC NULLS LAST)
    WHERE finished_at IS NULL
    """)

    execute("DROP INDEX IF EXISTS index_good_jobs_on_batch_callback_id_unfinished")
    execute("DROP INDEX IF EXISTS index_good_jobs_on_batch_id_unfinished")
    execute("DROP INDEX IF EXISTS index_good_job_batches_on_created_at_and_id")
    execute("DROP INDEX IF EXISTS index_good_job_batches_on_finished_at")
    execute("DROP INDEX IF EXISTS index_good_job_executions_on_scheduled_at")
    execute("DROP INDEX IF EXISTS index_good_jobs_dequeue_by_queue_scheduled_at")
    execute("DROP INDEX IF EXISTS index_good_jobs_dequeue_by_queue")
  end

  defp reorder_cron_index do
    execute("""
    DO $$
    DECLARE
      index_def text;
    BEGIN
      SELECT indexdef INTO index_def
      FROM pg_indexes
      WHERE schemaname = ANY (current_schemas(false))
        AND tablename = 'good_jobs'
        AND indexname = 'index_good_jobs_on_cron_key_and_cron_at_cond';

      IF index_def IS NULL OR position('cron_at DESC NULLS LAST' in index_def) = 0 THEN
        CREATE UNIQUE INDEX IF NOT EXISTS index_good_jobs_on_cron_key_and_cron_at_desc_cond
        ON good_jobs (cron_key, cron_at DESC NULLS LAST)
        WHERE cron_key IS NOT NULL;

        DROP INDEX IF EXISTS index_good_jobs_on_cron_key_and_cron_at_cond;

        ALTER INDEX IF EXISTS index_good_jobs_on_cron_key_and_cron_at_desc_cond
          RENAME TO index_good_jobs_on_cron_key_and_cron_at_cond;
      END IF;
    END $$;
    """)
  end
end
