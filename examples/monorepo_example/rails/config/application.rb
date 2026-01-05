require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module MonorepoExample
  class Application < Rails::Application
    config.load_defaults 8.0
    # Allow HTML views for interactive root page
    config.api_only = false

    # GoodJob configuration
    config.active_job.queue_adapter = :good_job
    config.good_job.execution_mode = :external
    config.good_job.poll_interval = 5
    config.good_job.max_threads = 5
    config.good_job.enable_cron = false
  end
end

