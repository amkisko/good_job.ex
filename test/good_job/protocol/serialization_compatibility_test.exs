defmodule GoodJob.Protocol.SerializationCompatibilityTest do
  @moduledoc """
  Tests for serialization format compatibility in Protocol integration.
  """

  use GoodJob.Test.Support.ProtocolSetup, async: false

  describe "Serialization format compatibility" do
    test "serialized_params matches ActiveJob format exactly" do
      ruby_serialized_params =
        Serialization.to_active_job(
          job_class: "MyApp::SendEmailJob",
          arguments: [%{"to" => "user@example.com", "subject" => "Hello"}],
          queue_name: "default",
          priority: 5,
          executions: 2,
          concurrency_key: "user_123",
          labels: ["important", "billing"]
        )

      # Verify all ActiveJob fields present
      assert ruby_serialized_params["job_class"] == "MyApp::SendEmailJob"
      assert ruby_serialized_params["queue_name"] == "default"
      assert ruby_serialized_params["priority"] == 5
      assert ruby_serialized_params["executions"] == 2
      assert ruby_serialized_params["good_job_concurrency_key"] == "user_123"
      assert ruby_serialized_params["good_job_labels"] == ["important", "billing"]
      assert is_list(ruby_serialized_params["arguments"])

      # Verify can deserialize back
      {:ok, job_class, arguments, executions, metadata} =
        Serialization.from_active_job(ruby_serialized_params)

      assert job_class == "MyApp::SendEmailJob"
      assert executions == 2
      assert Map.get(metadata, :concurrency_key) == "user_123"
      assert Map.get(metadata, :labels) == ["important", "billing"]
      assert length(arguments) == 1
    end

    test "deserializes Ruby format correctly" do
      # Simulate Ruby GoodJob serialized_params
      ruby_params = %{
        "job_class" => "MyApp::SendEmailJob",
        "job_id" => Ecto.UUID.generate(),
        "queue_name" => "default",
        "priority" => 0,
        "arguments" => [%{"to" => "user@example.com"}],
        "executions" => 0,
        "locale" => "en",
        "timezone" => "UTC"
      }

      {:ok, job_class, arguments, executions, metadata} =
        Serialization.from_active_job(ruby_params)

      assert job_class == "MyApp::SendEmailJob"
      assert executions == 0
      assert Map.get(metadata, :queue_name) == "default"
      assert Map.get(metadata, :priority) == 0
      assert length(arguments) == 1
    end
  end
end
