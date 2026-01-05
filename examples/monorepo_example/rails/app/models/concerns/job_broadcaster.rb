module JobBroadcaster
  extend ActiveSupport::Concern

  included do
    after_enqueue :broadcast_job_enqueued
    after_perform :broadcast_job_performed
    after_discard :broadcast_job_discarded
  end

  private

  def broadcast_job_enqueued
    ActionCable.server.broadcast("jobs", { type: "job_enqueued" })
  end

  def broadcast_job_performed
    ActionCable.server.broadcast("jobs", { type: "job_performed" })
  end

  def broadcast_job_discarded
    ActionCable.server.broadcast("jobs", { type: "job_discarded" })
  end
end

