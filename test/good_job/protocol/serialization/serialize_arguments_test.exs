defmodule GoodJob.Protocol.Serialization.SerializeArgumentsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "serialize_arguments/1" do
    test "serializes list of arguments" do
      args = [1, "hello", %{key: "value"}]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      assert is_list(serialized["arguments"])
    end

    test "serializes map arguments" do
      args = %{id: 1, name: "test"}

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      assert is_list(serialized["arguments"])
    end

    test "serializes map with atom keys and adds _aj_ruby2_keywords marker" do
      args = %{message: "hello", user_id: 123}

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      [arg] = serialized["arguments"]
      assert is_map(arg)
      assert arg["message"] == "hello"
      assert arg["user_id"] == 123
      # Should include _aj_ruby2_keywords marker for Rails keyword arguments
      assert Map.has_key?(arg, "_aj_ruby2_keywords")
      assert arg["_aj_ruby2_keywords"] == ["message", "user_id"]
    end

    test "serializes map with string keys without _aj_ruby2_keywords marker" do
      args = %{"message" => "hello", "user_id" => 123}

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      [arg] = serialized["arguments"]
      assert is_map(arg)
      assert arg["message"] == "hello"
      assert arg["user_id"] == 123
      # String keys don't need _aj_ruby2_keywords marker
      refute Map.has_key?(arg, "_aj_ruby2_keywords")
    end

    test "serializes nested structures" do
      args = [%{nested: %{deep: "value"}}]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      assert is_list(serialized["arguments"])
    end

    test "serializes Date in ActiveJob format" do
      date = ~D[2026-01-05]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [date],
          queue_name: "default"
        )

      [arg] = serialized["arguments"]
      assert arg["_aj_serialized"] == "ActiveJob::Serializers::DateSerializer"
      assert arg["value"] == "2026-01-05"
    end

    test "serializes DateTime in ActiveJob format" do
      dt = ~U[2026-01-05 12:30:45.123456Z]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [dt],
          queue_name: "default"
        )

      [arg] = serialized["arguments"]
      assert arg["_aj_serialized"] == "ActiveJob::Serializers::DateTimeSerializer"
      assert is_binary(arg["value"])
      assert String.contains?(arg["value"], "2026-01-05")
    end

    test "serializes NaiveDateTime in ActiveJob format" do
      naive_dt = ~N[2026-01-05 12:30:45.123456]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [naive_dt],
          queue_name: "default"
        )

      [arg] = serialized["arguments"]
      assert arg["_aj_serialized"] == "ActiveJob::Serializers::DateTimeSerializer"
      assert is_binary(arg["value"])
    end

    test "serializes atoms using SymbolSerializer format" do
      atom = :test_atom

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [atom],
          queue_name: "default"
        )

      [arg] = serialized["arguments"]
      assert arg["_aj_serialized"] == "ActiveJob::Serializers::SymbolSerializer"
      assert arg["value"] == "test_atom"
    end
  end
end
