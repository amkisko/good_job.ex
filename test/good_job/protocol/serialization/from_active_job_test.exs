defmodule GoodJob.Protocol.Serialization.FromActiveJobTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "from_active_job/1" do
    test "deserializes job from ActiveJob format" do
      serialized = %{
        "job_class" => "MyApp::MyJob",
        "job_id" => Ecto.UUID.generate(),
        "arguments" => [1, 2, 3],
        "executions" => 0
      }

      {:ok, job_class, args, executions, metadata} = Serialization.from_active_job(serialized)
      assert job_class == "MyApp::MyJob"
      assert args == [1, 2, 3]
      assert executions == 0
      assert is_map(metadata)
      # Use variables to avoid warnings
      _ = {args, executions}
    end

    test "handles missing executions field" do
      serialized = %{
        "job_class" => "MyApp::MyJob",
        "job_id" => Ecto.UUID.generate(),
        "arguments" => []
      }

      {:ok, job_class, args, executions, metadata} = Serialization.from_active_job(serialized)
      assert job_class == "MyApp::MyJob"
      assert args == []
      assert executions == 0
      assert is_map(metadata)
      # Use variables to avoid warnings
      _ = {args, executions}
    end

    test "extracts concurrency key" do
      serialized = %{
        "job_class" => "MyApp::MyJob",
        "job_id" => Ecto.UUID.generate(),
        "arguments" => [],
        "good_job_concurrency_key" => "test-key"
      }

      {:ok, job_class, _args, _executions, metadata} = Serialization.from_active_job(serialized)
      assert job_class == "MyApp::MyJob"
      assert metadata.concurrency_key == "test-key"
    end

    test "extracts labels" do
      serialized = %{
        "job_class" => "MyApp::MyJob",
        "job_id" => Ecto.UUID.generate(),
        "arguments" => [],
        "good_job_labels" => ["important"]
      }

      {:ok, job_class, _args, _executions, metadata} = Serialization.from_active_job(serialized)
      assert job_class == "MyApp::MyJob"
      assert metadata.labels == ["important"]
    end
  end

  describe "from_active_job/1 error cases" do
    test "returns error for non-map input" do
      assert Serialization.from_active_job("not a map") == {:error, "serialized_params must be a map"}
    end

    test "returns error for missing job_class" do
      serialized = %{"arguments" => []}
      assert {:error, _} = Serialization.from_active_job(serialized)
    end
  end
end
