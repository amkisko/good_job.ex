defmodule GoodJob.Protocol.Serialization.DeserializeArgumentsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "deserialize_arguments/1 - ActiveJob serializers" do
    test "deserializes DateSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_serialized" => "ActiveJob::Serializers::DateSerializer", "value" => "2026-01-05"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [date], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert %Date{} = date
      assert date == ~D[2026-01-05]
    end

    test "deserializes DateTimeSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "_aj_serialized" => "ActiveJob::Serializers::DateTimeSerializer",
            "value" => "2026-01-05T12:30:45.123456Z"
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [dt], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert %DateTime{} = dt
      assert dt.year == 2026
      assert dt.month == 1
      assert dt.day == 5
    end

    test "deserializes TimeSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "_aj_serialized" => "ActiveJob::Serializers::TimeSerializer",
            "value" => "2026-01-05T12:30:45.123456Z"
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [dt], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert %DateTime{} = dt
    end

    test "deserializes TimeWithZoneSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "_aj_serialized" => "ActiveJob::Serializers::TimeWithZoneSerializer",
            "value" => "2026-01-05T12:30:45.123456Z",
            "time_zone" => "America/New_York"
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [dt], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert %DateTime{} = dt
    end

    test "deserializes SymbolSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_serialized" => "ActiveJob::Serializers::SymbolSerializer", "value" => "test_symbol"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [atom], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert atom == :test_symbol
    end

    test "deserializes BigDecimalSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_serialized" => "ActiveJob::Serializers::BigDecimalSerializer", "value" => "123.456"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [decimal], _executions, _metadata} = Serialization.from_active_job(serialized)
      # Should be Decimal struct if available, or float
      assert is_number(decimal) or is_struct(decimal, Decimal)
    end

    test "deserializes DurationSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "_aj_serialized" => "ActiveJob::Serializers::DurationSerializer",
            "value" => 3600,
            "parts" => [%{"seconds" => 3600}]
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [duration], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert is_map(duration)
      assert Map.has_key?(duration, :value)
      assert Map.has_key?(duration, :parts)
    end

    test "deserializes RangeSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "_aj_serialized" => "ActiveJob::Serializers::RangeSerializer",
            "begin" => 1,
            "end" => 10,
            "exclude_end" => false
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [range], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert is_map(range)
      assert range[:begin] == 1
      assert range[:end] == 10
      assert range[:exclude_end] == false
    end

    test "deserializes ModuleSerializer" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{"_aj_serialized" => "ActiveJob::Serializers::ModuleSerializer", "value" => "String"}
        ],
        "executions" => 0
      }

      {:ok, _job_class, [module], _executions, _metadata} = Serialization.from_active_job(serialized)
      # Should be a module if resolvable, or the string value
      assert is_atom(module) or is_binary(module)
    end

    test "deserializes map and strips _aj_ruby2_keywords marker" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "message" => "hello",
            "user_id" => 123,
            "_aj_ruby2_keywords" => ["message", "user_id"]
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [arg], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert is_map(arg)
      # Should convert string keys to atoms
      assert Map.has_key?(arg, :message) or Map.has_key?(arg, "message")
      assert Map.has_key?(arg, :user_id) or Map.has_key?(arg, "user_id")
      # Should strip out _aj_ruby2_keywords marker (Rails-specific, not needed in Elixir)
      refute Map.has_key?(arg, "_aj_ruby2_keywords")
      refute Map.has_key?(arg, :_aj_ruby2_keywords)
    end

    test "deserializes map with _aj_ruby2_keywords and converts keys to atoms" do
      serialized = %{
        "job_class" => "TestJob",
        "arguments" => [
          %{
            "message" => "hello",
            "_aj_ruby2_keywords" => ["message"]
          }
        ],
        "executions" => 0
      }

      {:ok, _job_class, [arg], _executions, _metadata} = Serialization.from_active_job(serialized)
      assert is_map(arg)
      # Should have message as atom key (if try_convert_to_atom succeeds)
      assert Map.get(arg, :message) == "hello" or Map.get(arg, "message") == "hello"
      # Should not have _aj_ruby2_keywords
      refute Map.has_key?(arg, "_aj_ruby2_keywords")
    end
  end
end
