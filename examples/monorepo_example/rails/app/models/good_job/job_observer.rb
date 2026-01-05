module GoodJob
  class JobObserver
    def self.observe
      ActiveSupport::Notifications.subscribe("good_job.perform_job") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        job = event.payload[:job]
        Rails.logger.info "JobObserver: job_performed for job_id=#{job.id}, broadcasting to jobs channel"
        
        # Broadcast immediately
        ActionCable.server.broadcast("jobs", { type: "job_performed", job_id: job.id })
        
        # Also broadcast after a short delay to catch status updates
        # This ensures the database has been updated before we refresh
        Thread.new do
          sleep 0.5
          ActionCable.server.broadcast("jobs", { type: "job_succeeded", job_id: job.id })
        end
      end

      ActiveSupport::Notifications.subscribe("good_job.discard_job") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        job = event.payload[:job]
        Rails.logger.info "JobObserver: job_discarded for job_id=#{job.id}, broadcasting to jobs channel"
        ActionCable.server.broadcast("jobs", { type: "job_discarded", job_id: job.id })
      end

      ActiveSupport::Notifications.subscribe("good_job.retry_job") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        job = event.payload[:job]
        Rails.logger.info "JobObserver: job_retried for job_id=#{job.id}, broadcasting to jobs channel"
        ActionCable.server.broadcast("jobs", { type: "job_retried", job_id: job.id })
      end

      ActiveSupport::Notifications.subscribe("good_job.enqueue_job") do |*args|
        event = ActiveSupport::Notifications::Event.new(*args)
        active_job = event.payload[:active_job]
        Rails.logger.info "JobObserver: job_enqueued, broadcasting to jobs channel"
        ActionCable.server.broadcast("jobs", { type: "job_enqueued" })
      end
    end
  end
end

