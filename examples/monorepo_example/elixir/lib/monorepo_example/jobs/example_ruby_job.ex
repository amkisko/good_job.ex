defmodule MonorepoExample.Jobs.ExampleRubyJob do
  @moduledoc """
  This job will be processed by Ruby worker.
  The job logic is in Ruby, this is just metadata.
  """
  use GoodJob.ExternalJob, queue: "rb.default"

  @impl GoodJob.Behaviour
  def perform(_args) do
    raise "ExampleRubyJob must be processed by Ruby worker, not Elixir!"
  end
end
