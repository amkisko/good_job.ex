class ZigProcessedJob < ApplicationJob
  # This job will be processed by Zig worker
  # The job logic is in Zig, this is just metadata
  
  # Queue will be automatically prefixed with "zig." for Zig processing
  queue_as "zig.default"

  # Prevent local execution - this job must be processed by Zig
  def perform(*args)
    raise "ZigProcessedJob must be processed by Zig worker, not Ruby!"
  end
end

