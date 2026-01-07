defmodule GoodJob.Protocol.Serialization.GlobalidTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "GlobalID deserialization" do
    test "deserializes GlobalID from ActiveJob format" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_globalid" => "gid://myapp/User/123"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [user], _executions, _metadata} = Serialization.from_active_job(serialized)

      assert %{__struct__: :global_id, app: "myapp", model: "User", id: "123", gid: "gid://myapp/User/123"} = user
    end

    test "deserializes GlobalID with different app name" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_globalid" => "gid://production/Order/456"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [order], _executions, _metadata} = Serialization.from_active_job(serialized)

      assert %{__struct__: :global_id, app: "production", model: "Order", id: "456", gid: "gid://production/Order/456"} =
               order
    end

    test "deserializes GlobalID nested in a map" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "user" => %{"_aj_globalid" => "gid://myapp/User/789"},
            "action" => "process"
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [args], _executions, _metadata} = Serialization.from_active_job(serialized)

      user = Map.get(args, "user") || Map.get(args, :user)
      assert %{__struct__: :global_id, app: "myapp", model: "User", id: "789"} = user
      assert Map.get(args, "action") == "process" || Map.get(args, :action) == "process"
    end

    test "deserializes GlobalID in array" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          [
            %{"_aj_globalid" => "gid://myapp/User/1"},
            %{"_aj_globalid" => "gid://myapp/User/2"}
          ]
        ],
        "executions" => 0
      }

      {:ok, _job_class, [users], _executions, _metadata} = Serialization.from_active_job(serialized)

      assert is_list(users)
      assert length(users) == 2

      assert Enum.all?(users, fn user ->
               %{__struct__: :global_id} = user
             end)
    end

    test "handles invalid GlobalID format gracefully" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_globalid" => "invalid-format"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [result], _executions, _metadata} = Serialization.from_active_job(serialized)

      # Should return the string as-is if parsing fails
      assert result == "invalid-format"
    end

    test "handles GlobalID with missing parts" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_globalid" => "gid://myapp"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [result], _executions, _metadata} = Serialization.from_active_job(serialized)

      # Should return the string as-is if parsing fails
      assert result == "gid://myapp"
    end

    test "handles GlobalID in nested hash structure" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "data" => %{
              "user" => %{"_aj_globalid" => "gid://myapp/User/999"},
              "metadata" => %{"key" => "value"}
            }
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [args], _executions, _metadata} = Serialization.from_active_job(serialized)

      data = Map.get(args, "data") || Map.get(args, :data)
      user = Map.get(data, "user") || Map.get(data, :user)
      assert %{__struct__: :global_id, app: "myapp", model: "User", id: "999"} = user
    end

    test "handles GlobalID mixed with other serialized types" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "user" => %{"_aj_globalid" => "gid://myapp/User/123"},
            "date" => %{"_aj_serialized" => "ActiveJob::Serializers::DateSerializer", "value" => "2026-01-05"},
            "message" => "hello"
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [args], _executions, _metadata} = Serialization.from_active_job(serialized)

      user = Map.get(args, "user") || Map.get(args, :user)
      assert %{__struct__: :global_id} = user

      date = Map.get(args, "date") || Map.get(args, :date)
      assert %Date{} = date

      message = Map.get(args, "message") || Map.get(args, :message)
      assert message == "hello"
    end

    test "preserves GlobalID structure for later resolution" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_globalid" => "gid://myapp/User/123"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [user], _executions, _metadata} = Serialization.from_active_job(serialized)

      # The GlobalID struct should contain all information needed to resolve the record
      assert user.app == "myapp"
      assert user.model == "User"
      assert user.id == "123"
      assert user.gid == "gid://myapp/User/123"
    end
  end

  describe "GlobalID serialization detection" do
    test "detects GlobalID format correctly" do
      # GlobalID should be detected when hash has exactly one key "_aj_globalid"
      globalid_hash = %{"_aj_globalid" => "gid://myapp/User/123"}

      # This is tested through the deserialization process
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [globalid_hash],
        "executions" => 0
      }

      {:ok, _job_class, [result], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert %{__struct__: :global_id} = result
    end

    test "does not treat regular hash as GlobalID" do
      # Regular hash with _aj_globalid but other keys should not be treated as GlobalID
      regular_hash = %{
        "_aj_globalid" => "gid://myapp/User/123",
        "other_key" => "value"
      }

      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [regular_hash],
        "executions" => 0
      }

      {:ok, _job_class, [result], _executions, _metadata} = Serialization.from_active_job(serialized)

      # Should be treated as regular map, not GlobalID
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert Map.has_key?(result, "other_key") || Map.has_key?(result, :other_key)
    end
  end
end
