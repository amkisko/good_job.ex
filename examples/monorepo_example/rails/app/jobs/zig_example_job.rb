class ZigExampleJob < ApplicationJob
  # This job will be processed by Zig worker
  queue_as "zig.default"

  # Prevent local execution - this job must be processed by Zig
  def perform(*args)
    raise "ZigExampleJob must be processed by Zig worker, not Ruby!"
  end
end

