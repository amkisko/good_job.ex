class ScheduledRubyJob < ApplicationJob
  queue_as "rb.default"

  def perform(message: "Scheduled from Rails cron")
    Rails.logger.info "ScheduledRubyJob executed: #{message} at #{Time.current}"
    puts "[Rails Cron] ScheduledRubyJob: #{message} at #{Time.current}"
  end
end

