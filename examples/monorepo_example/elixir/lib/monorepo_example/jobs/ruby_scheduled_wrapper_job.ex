defmodule MonorepoExample.Jobs.ScheduledRubyJob do
  @moduledoc """
  This job will be processed by Ruby worker.
  The job logic is in Ruby, this is just metadata.
  """
  use GoodJob.ExternalJob, queue: "rb.default"

  # Prevent local execution - this job must be processed by Ruby
  @impl GoodJob.Behaviour
  def perform(_args) do
    raise "ScheduledRubyJob must be processed by Ruby worker, not Elixir!"
  end
end
