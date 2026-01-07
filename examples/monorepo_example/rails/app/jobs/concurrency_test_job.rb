class ConcurrencyTestJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as "ex.default"

  # Test concurrency configuration
  # This should match Ruby good_job behavior exactly
  good_job_control_concurrency_with(
    total_limit: 2,
    key: -> { 
      args = arguments.first || {}
      args[:key] || args["key"] || "default"
    }
  )

  def perform(*args)
    raise "ConcurrencyTestJob must be processed by Elixir worker, not Ruby!"
  end
end

