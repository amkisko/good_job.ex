class GlobalidTestJob < ApplicationJob
  queue_as "ex.default"

  # This job tests GlobalID resolution
  # It should receive a User object (via GlobalID) and process it
  def perform(*args)
    raise "GlobalidTestJob must be processed by Elixir worker, not Ruby!"
  end
end

