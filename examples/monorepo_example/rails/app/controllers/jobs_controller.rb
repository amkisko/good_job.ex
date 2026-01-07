class JobsController < ApplicationController
  def enqueue
    job_type = params[:job_type] || "example"
    
    case job_type
    when "example"
      job = ExampleJob.perform_later(message: params[:message] || "Hello from Rails!")
    when "elixir"
      job = ElixirProcessedJob.perform_later(
        user_id: params[:user_id] || 123,
        action: params[:action] || "process"
      )
    when "zig"
      job = ZigProcessedJob.perform_later(
        message: params[:message] || "Hello from Rails to Zig!"
      )
    when "zig_example"
      job = ZigExampleJob.perform_later(
        message: params[:message] || "Example job for Zig"
      )
    when "globalid"
      # Test GlobalID resolution
      user = User.find(rand(1..100))
      job = GlobalidTestJob.perform_later(
        user: user,
        message: "GlobalID test from Rails UI at #{Time.current}"
      )
    when "concurrency"
      # Test concurrency limits
      resource_id = params[:resource_id] || rand(1..10).to_s
      job = ConcurrencyTestJob.perform_later(
        key: resource_id,
        message: "Concurrency test from Rails UI at #{Time.current}"
      )
    when "cross_language_concurrency"
      # Test cross-language concurrency
      resource_id = params[:resource_id] || rand(1..5).to_s
      job = CrossLanguageConcurrencyJob.perform_later(
        resource_id: resource_id,
        action: "process"
      )
    else
      if request.format.html?
        redirect_to root_path, alert: "Unknown job type: #{job_type}"
      else
        render json: { error: "Unknown job type" }, status: :bad_request
      end
      return
    end
    
    # Broadcast job update
    ActionCable.server.broadcast("jobs", { type: "job_enqueued", job_type: job_type })
    
    if request.format.html?
      redirect_to root_path, notice: "Job enqueued successfully: #{job_type}"
    else
      render json: { status: "enqueued", job_type: job_type }
    end
  end
end


