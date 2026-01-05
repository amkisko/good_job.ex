class ElixirProcessedJob < ApplicationJob
  # This job will be processed by Elixir worker
  # The job logic is in Elixir, this is just metadata
  
  # Queue will be automatically prefixed with "ex." for Elixir processing
  queue_as "ex.default"

  # Prevent local execution - this job must be processed by Elixir
  def perform(*args)
    raise "ElixirProcessedJob must be processed by Elixir worker, not Ruby!"
  end
end

