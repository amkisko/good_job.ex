defmodule GoodJob.Protocol.Serialization.RoundTripTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "round-trip serialization" do
    test "Date round-trip" do
      date = ~D[2026-01-05]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [date],
          queue_name: "default"
        )

      {:ok, _job_class, [deserialized_date], _executions, _metadata} =
        Serialization.from_active_job(serialized)

      assert deserialized_date == date
    end

    test "DateTime round-trip" do
      dt = ~U[2026-01-05 12:30:45.123456Z]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [dt],
          queue_name: "default"
        )

      {:ok, _job_class, [deserialized_dt], _executions, _metadata} =
        Serialization.from_active_job(serialized)

      assert deserialized_dt == dt
    end

    test "atom round-trip" do
      atom = :test_atom

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: [atom],
          queue_name: "default"
        )

      {:ok, _job_class, [deserialized_atom], _executions, _metadata} =
        Serialization.from_active_job(serialized)

      assert deserialized_atom == atom
    end

    test "mixed types round-trip" do
      args = [
        ~D[2026-01-05],
        ~U[2026-01-05 12:30:45Z],
        :test_symbol,
        "string",
        123,
        %{key: "value"}
      ]

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      {:ok, _job_class, deserialized_args, _executions, _metadata} =
        Serialization.from_active_job(serialized)

      assert length(deserialized_args) == 6
      assert Enum.at(deserialized_args, 0) == ~D[2026-01-05]
      assert %DateTime{} = Enum.at(deserialized_args, 1)
      assert Enum.at(deserialized_args, 2) == :test_symbol
      assert Enum.at(deserialized_args, 3) == "string"
      assert Enum.at(deserialized_args, 4) == 123
      assert is_map(Enum.at(deserialized_args, 5))
    end

    test "map with atom keys round-trip (Elixir -> Rails -> Elixir)" do
      # Simulate Elixir enqueueing a job for Rails
      args = %{message: "hello", user_id: 123}

      serialized =
        Serialization.to_active_job(
          job_class: "TestJob",
          arguments: args,
          queue_name: "default"
        )

      # Verify _aj_ruby2_keywords was added
      [arg] = serialized["arguments"]
      assert arg["_aj_ruby2_keywords"] == ["message", "user_id"]

      # Simulate Rails deserializing (would use the marker)
      # Then Elixir deserializing back (should strip the marker)
      {:ok, _job_class, deserialized_args, _executions, _metadata} =
        Serialization.from_active_job(serialized)

      [deserialized_arg] = deserialized_args
      assert is_map(deserialized_arg)
      # Should have the values
      assert Map.get(deserialized_arg, :message) == "hello" or Map.get(deserialized_arg, "message") == "hello"
      assert Map.get(deserialized_arg, :user_id) == 123 or Map.get(deserialized_arg, "user_id") == 123
      # Should NOT have _aj_ruby2_keywords (stripped during deserialization)
      refute Map.has_key?(deserialized_arg, "_aj_ruby2_keywords")
      refute Map.has_key?(deserialized_arg, :_aj_ruby2_keywords)
    end

    test "map with _aj_ruby2_keywords round-trip (Rails -> Elixir)" do
      # Simulate Rails enqueueing a job for Elixir
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "message" => "hello",
            "user_id" => 123,
            "_aj_ruby2_keywords" => ["message", "user_id"]
          }
        ],
        "executions" => 0,
        "queue_name" => "default"
      }

      # Elixir deserializes (should strip _aj_ruby2_keywords)
      {:ok, _job_class, [deserialized_arg], _executions, _metadata} =
        Serialization.from_active_job(serialized)

      assert is_map(deserialized_arg)
      # Should have the values
      assert Map.get(deserialized_arg, :message) == "hello" or Map.get(deserialized_arg, "message") == "hello"
      assert Map.get(deserialized_arg, :user_id) == 123 or Map.get(deserialized_arg, "user_id") == 123
      # Should NOT have _aj_ruby2_keywords
      refute Map.has_key?(deserialized_arg, "_aj_ruby2_keywords")
      refute Map.has_key?(deserialized_arg, :_aj_ruby2_keywords)
    end
  end
end
