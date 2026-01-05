# GoodJob configuration
Rails.application.configure do
  config.good_job = ActiveSupport::OrderedOptions.new
  config.good_job.execution_mode = :external
  # With LISTEN/NOTIFY enabled, polling is just a fallback safety net
  # Recommended 30+ seconds when LISTEN/NOTIFY is enabled
  # This reduces unnecessary database queries while maintaining reliability
  config.good_job.poll_interval = 30
  config.good_job.max_threads = 5
  config.good_job.enable_cron = true
  # Process rb.default queue - Elixir worker handles ex.default queue
  # Note: Ruby GoodJob doesn't support wildcard patterns, so we list exact queue names
  config.good_job.queues = "rb.default"
  # Cleanup stale processes and unlock orphaned jobs
  config.good_job.cleanup_preserved_jobs_before_seconds_ago = 86400 # 24 hours
  
  # Cron jobs configuration
  config.good_job.cron = {
    # Ruby cron job - runs every minute
    ruby_scheduled: {
      cron: "*/1 * * * *", # Every minute
      class: "ScheduledRubyJob",
      description: "Scheduled Ruby job that runs every minute",
      set: { queue: "rb.default" }
    },
    # Elixir cron job - runs every 2 minutes
    elixir_scheduled: {
      cron: "*/2 * * * *", # Every 2 minutes
      class: "ElixirProcessedJob",
      description: "Scheduled Elixir job that runs every 2 minutes",
      args: -> { [{ user_id: rand(1000..9999), action: "scheduled_task" }] },
      set: { queue: "ex.default" }
    }
  }
  
  # Ensure Process.cleanup runs periodically to unlock stale jobs
  # This is called automatically by GoodJob::Process#refresh_if_stale when workers are running
  # We also add a cleanup cron job to handle stale locks even when workers aren't running
  config.good_job.cron[:cleanup_stale_locks] = {
    cron: "*/5 * * * *", # Every 5 minutes
    class: "CleanupStaleLocksJob",
    description: "Cleanup stale process locks and unlock orphaned jobs",
    set: { queue: "rb.default" }
  }
end

# Initialize JobObserver for ActionCable broadcasting
Rails.application.config.after_initialize do
  GoodJob::JobObserver.observe
end

