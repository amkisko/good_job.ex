class CrossLanguageConcurrencyJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  # This job can be processed by either Ruby or Elixir workers
  # The concurrency limit applies across BOTH languages

  # Queue can be processed by either worker
  queue_as "ex.default"  # Processed by Elixir worker
  # Or use "rb.default" for Ruby worker

  # Concurrency configuration - limits apply across all workers
  good_job_control_concurrency_with(
    total_limit: 2,  # Maximum 2 concurrent jobs across ALL workers (Ruby + Elixir)
    key: -> {
      # Generate concurrency key from job arguments
      args = arguments.first || {}
      key = args[:resource_id] || args["resource_id"] || "default"
      "resource:#{key}"
    }
  )

  def perform(resource_id:, action: "process")
    # This will be processed by Elixir worker
    # But concurrency limits are enforced across Ruby and Elixir
    Rails.logger.info "CrossLanguageConcurrencyJob: resource_id=#{resource_id}, action=#{action}"
    puts "[Cross-Language] Processing resource #{resource_id} with action #{action}"

    # Simulate work
    sleep(2)

    Rails.logger.info "CrossLanguageConcurrencyJob: Completed resource_id=#{resource_id}"
  end
end

