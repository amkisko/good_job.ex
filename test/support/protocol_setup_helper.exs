defmodule GoodJob.Test.Support.ProtocolSetup do
  @moduledoc """
  Shared setup for Protocol integration tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use GoodJob.Testing.JobCase

      alias GoodJob.{Job, JobExecutor, Protocol, Repo}
      alias GoodJob.Protocol.{Deserializer, Serialization}

      @moduletag :integration
      @moduletag :protocol
    end
  end

  setup do
    # Save original external_jobs config
    original_external_jobs = GoodJob.Config.external_jobs()

    # Configure external_jobs mapping for test jobs
    current_config = Application.get_env(:good_job, :config, %{})

    test_external_jobs = %{
      "MyApp::SendEmailJob" => GoodJob.Protocol.TestJobs.EmailJob,
      "MyApp::ProcessPaymentJob" => GoodJob.Protocol.TestJobs.PaymentJob,
      "TestJobs.PaymentJob" => GoodJob.Protocol.TestJobs.PaymentJob
    }

    Application.put_env(:good_job, :config, Map.put(current_config, :external_jobs, test_external_jobs))

    on_exit(fn ->
      # Restore original config
      current_config = Application.get_env(:good_job, :config, %{})
      restored_config = Map.put(current_config, :external_jobs, original_external_jobs)
      Application.put_env(:good_job, :config, restored_config)
    end)

    :ok
  end
end
