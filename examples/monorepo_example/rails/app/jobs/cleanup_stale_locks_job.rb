class CleanupStaleLocksJob < ApplicationJob
  queue_as "rb.default"

  def perform
    # Cleanup stale processes
    GoodJob::Process.cleanup
    
    # Unlock jobs that have been locked for more than 1 minute but aren't finished
    # This handles cases where a worker crashed after locking a job
    stale_cutoff = 1.minute.ago
    stale_count = GoodJob::Job
      .where("locked_at < ? AND finished_at IS NULL", stale_cutoff)
      .where.not(locked_by_id: nil)
      .update_all(locked_by_id: nil, locked_at: nil, performed_at: nil)
    
    Rails.logger.info "CleanupStaleLocksJob: Unlocked #{stale_count} stale jobs" if stale_count > 0
  end
end

