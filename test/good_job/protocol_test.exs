defmodule GoodJob.ProtocolTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.Protocol
  alias GoodJob.Repo
  alias GoodJob.Job

  defmodule ProtocolJob do
    use GoodJob.Job

    def perform(_args), do: :ok
  end

  defmodule ExternalMappedJob do
    use GoodJob.Job

    def perform(_args), do: :ok
  end

  setup do
    original_config = Application.get_env(:good_job, :config, %{})

    on_exit(fn ->
      Application.put_env(:good_job, :config, original_config)
    end)

    Application.put_env(:good_job, :config, Map.put(original_config, :repo, GoodJob.TestRepo))

    :ok
  end

  test "enqueue_for_external with external class name" do
    {:ok, job} = Protocol.enqueue_for_external("MyApp::SendEmailJob", %{to: "user@example.com"})

    assert job.job_class == "MyApp::SendEmailJob"
    assert job.queue_name == "default"

    reloaded = Repo.repo().get!(Job, job.id)
    assert reloaded.serialized_params["job_class"] == "MyApp::SendEmailJob"
  end

  test "enqueue_for_external with elixir module" do
    {:ok, job} = Protocol.enqueue_for_external(ProtocolJob, %{value: 1})

    assert job.job_class == "GoodJob::ProtocolTest::ProtocolJob"
    assert job.serialized_params["job_class"] == "GoodJob::ProtocolTest::ProtocolJob"
  end

  test "enqueue_for_elixir resolves external class via mapping" do
    Application.put_env(:good_job, :config, %{
      repo: GoodJob.TestRepo,
      external_jobs: %{"External::Job" => ExternalMappedJob}
    })

    {:ok, job} = Protocol.enqueue_for_elixir("External::Job", %{value: 1})
    assert job.job_class == "Elixir.GoodJob.ProtocolTest.ExternalMappedJob"
  end
end
