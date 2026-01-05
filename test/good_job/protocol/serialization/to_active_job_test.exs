defmodule GoodJob.Protocol.Serialization.ToActiveJobTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "to_active_job/1" do
    test "serializes job with required fields" do
      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [1, 2, 3],
          queue_name: "default"
        )

      assert serialized["job_class"] == "MyApp::MyJob"
      assert serialized["arguments"] == [1, 2, 3]
      assert serialized["queue_name"] == "default"
    end

    test "serializes with optional fields" do
      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [],
          queue_name: "default",
          priority: 5,
          executions: 2,
          locale: "fr",
          timezone: "America/New_York"
        )

      assert serialized["priority"] == 5
      assert serialized["executions"] == 2
      assert serialized["locale"] == "fr"
      assert serialized["timezone"] == "America/New_York"
    end

    test "serializes with concurrency key" do
      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [],
          queue_name: "default",
          concurrency_key: "test-key"
        )

      assert serialized["good_job_concurrency_key"] == "test-key"
    end

    test "serializes with labels" do
      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [],
          queue_name: "default",
          labels: ["important", "billing"]
        )

      assert serialized["good_job_labels"] == ["important", "billing"]
    end

    test "serializes with notify flag" do
      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [],
          queue_name: "default",
          notify: true
        )

      assert serialized["good_job_notify"] == true
    end

    test "generates job_id if not provided" do
      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [],
          queue_name: "default"
        )

      assert is_binary(serialized["job_id"])
    end

    test "uses provided job_id" do
      job_id = Ecto.UUID.generate()

      serialized =
        Serialization.to_active_job(
          job_class: "MyApp::MyJob",
          arguments: [],
          queue_name: "default",
          job_id: job_id
        )

      assert serialized["job_id"] == job_id
    end
  end
end
