class HomeController < ApplicationController
  def index
    # Convert to array to ensure it's evaluated and can be used in Phlex components
    @jobs = GoodJob::Job.order(created_at: :desc).limit(50).to_a
    @stats = {
      queued: GoodJob::Job.queued.count,
      running: GoodJob::Job.running.count,
      finished: GoodJob::Job.finished.count,
      discarded: GoodJob::Job.discarded.count,
      scheduled: GoodJob::Job.scheduled.count
    }
  end

  def stats
    @stats = {
      queued: GoodJob::Job.queued.count,
      running: GoodJob::Job.running.count,
      finished: GoodJob::Job.finished.count,
      discarded: GoodJob::Job.discarded.count,
      scheduled: GoodJob::Job.scheduled.count
    }
    render partial: "home/stats", locals: { stats: @stats }
  end

  def jobs
    @jobs = GoodJob::Job.order(created_at: :desc).limit(50).to_a
    render partial: "home/jobs", locals: { jobs: @jobs }
  end
end

