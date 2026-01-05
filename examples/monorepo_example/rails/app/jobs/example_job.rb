class ExampleJob < ApplicationJob
  queue_as "rb.default"

  def perform(message:)
    Rails.logger.info "ExampleJob processed: #{message}"
    puts "[Rails Worker] ExampleJob: #{message}"
  end
end

