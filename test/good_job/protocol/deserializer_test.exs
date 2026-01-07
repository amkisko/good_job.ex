defmodule GoodJob.Protocol.DeserializerTest do
  use ExUnit.Case, async: true

  alias GoodJob.{Config, Protocol.Deserializer}

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args), do: :ok
  end

  defmodule MappedJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args), do: :ok
  end

  setup do
    # Save original config
    original_config = Application.get_env(:good_job, :config, %{})
    original_external_jobs = Config.external_jobs()

    on_exit(fn ->
      # Restore original config
      current_config = Application.get_env(:good_job, :config, %{})
      restored_config = Map.put(current_config, :external_jobs, original_external_jobs)
      Application.put_env(:good_job, :config, restored_config)
    end)

    %{original_external_jobs: original_external_jobs, original_config: original_config}
  end

  describe "deserialize_job_module/2" do
    test "resolves Elixir-native job module automatically" do
      job_class = "GoodJob.Protocol.DeserializerTest.TestJob"
      invalid_params = %{"invalid" => "data"}

      # Elixir-native jobs should resolve automatically without configuration
      module = Deserializer.deserialize_job_module(job_class, invalid_params)
      assert module == TestJob
    end

    test "resolves Elixir-native job module with Elixir. prefix" do
      job_class = "Elixir.GoodJob.Protocol.DeserializerTest.TestJob"
      invalid_params = %{"invalid" => "data"}

      module = Deserializer.deserialize_job_module(job_class, invalid_params)
      assert module == TestJob
    end

    test "resolves cross-language job module from external_jobs configuration" do
      # Configure external_jobs mapping
      current_config = Application.get_env(:good_job, :config, %{})

      Application.put_env(
        :good_job,
        :config,
        Map.put(current_config, :external_jobs, %{
          "External::TestJob" => MappedJob
        })
      )

      job_class = "External::TestJob"
      invalid_params = %{"invalid" => "data"}

      # Should resolve using external_jobs configuration
      module = Deserializer.deserialize_job_module(job_class, invalid_params)
      assert module == MappedJob
    end

    test "raises error when external_jobs module not found" do
      # Configure external_jobs with non-existent module
      current_config = Application.get_env(:good_job, :config, %{})

      Application.put_env(
        :good_job,
        :config,
        Map.put(current_config, :external_jobs, %{
          "External::NonExistentJob" => :NonExistentModule
        })
      )

      job_class = "External::NonExistentJob"
      invalid_params = %{"invalid" => "data"}

      assert_raise RuntimeError, ~r/Job module configured in external_jobs not found/, fn ->
        Deserializer.deserialize_job_module(job_class, invalid_params)
      end
    end

    test "resolves module from active_job format when available" do
      job_class = "MyApp::MyJob"

      serialized_params = %{
        "job_class" => "GoodJob.Protocol.DeserializerTest.TestJob",
        "job_id" => Ecto.UUID.generate(),
        "arguments" => []
      }

      module = Deserializer.deserialize_job_module(job_class, serialized_params)
      assert module == TestJob
    end

    test "raises error with helpful message for unknown Rails job" do
      job_class = "Rails::UnknownJob"
      invalid_params = %{"invalid" => "data"}

      assert_raise RuntimeError, ~r/Job module not found.*For external jobs, configure it in external_jobs/, fn ->
        Deserializer.deserialize_job_module(job_class, invalid_params)
      end
    end

    test "raises error with helpful message for unknown Elixir job" do
      job_class = "NonExistent.Module.Job"
      invalid_params = %{"invalid" => "data"}

      assert_raise RuntimeError, ~r/Job module not found.*For Elixir jobs, ensure the module name matches/, fn ->
        Deserializer.deserialize_job_module(job_class, invalid_params)
      end
    end
  end

  describe "deserialize_args/1" do
    test "extracts arguments from active_job format" do
      serialized_params = %{
        "job_class" => "TestJob",
        "job_id" => Ecto.UUID.generate(),
        "arguments" => [1, 2, 3]
      }

      args = Deserializer.deserialize_args(serialized_params)
      assert args == [1, 2, 3]
    end

    test "extracts arguments from simple map format" do
      serialized_params = %{"arguments" => ["test", "data"]}
      args = Deserializer.deserialize_args(serialized_params)
      assert args == ["test", "data"]
    end

    test "returns empty list for nil" do
      assert Deserializer.deserialize_args(nil) == []
    end

    test "handles missing arguments key" do
      serialized_params = %{"job_class" => "TestJob"}
      args = Deserializer.deserialize_args(serialized_params)
      assert args == []
    end
  end

  describe "normalize_args_for_elixir/3" do
    test "normalizes single map with symbol keys" do
      args = [
        %{
          "_aj_symbol_keys" => ["key1", "key2"],
          "key1" => "value1",
          "key2" => "value2",
          "key3" => "value3"
        }
      ]

      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)
      assert Map.has_key?(normalized, :key1) or Map.has_key?(normalized, "key1")
    end

    test "normalizes single map with ruby2 keywords" do
      args = [
        %{
          "_aj_ruby2_keywords" => ["key1"],
          "key1" => "value1"
        }
      ]

      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)
    end

    test "normalizes single map with hash_with_indifferent_access" do
      args = [
        %{
          "_aj_hash_with_indifferent_access" => true,
          "key1" => "value1"
        }
      ]

      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)
    end

    test "normalizes list of maps by merging" do
      args = [
        %{"key1" => "value1"},
        %{"key2" => "value2"}
      ]

      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)
    end

    test "normalizes direct map" do
      args = %{"key1" => "value1", "key2" => "value2"}
      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)
    end

    test "returns other types unchanged" do
      assert Deserializer.normalize_args_for_elixir(TestJob, "string", %{}) == "string"
      assert Deserializer.normalize_args_for_elixir(TestJob, 123, %{}) == 123
      assert Deserializer.normalize_args_for_elixir(TestJob, [:atom], %{}) == [:atom]
    end

    test "handles empty list" do
      assert Deserializer.normalize_args_for_elixir(TestJob, [], %{}) == []
    end

    test "removes ActiveJob internal keys" do
      args = [
        %{
          "_aj_symbol_keys" => ["key1"],
          "_aj_ruby2_keywords" => [],
          "_aj_hash_with_indifferent_access" => true,
          "_aj_globalid" => "gid://myapp/User/123",
          "_aj_serialized" => "data",
          "key1" => "value1",
          "normal_key" => "value"
        }
      ]

      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)
      refute Map.has_key?(normalized, "_aj_symbol_keys")
      refute Map.has_key?(normalized, "_aj_ruby2_keywords")
      refute Map.has_key?(normalized, "_aj_hash_with_indifferent_access")
      # Note: _aj_globalid is handled in Serialization.deserialize_argument, not deleted here
    end

    test "handles GlobalID in arguments" do
      args = [
        %{
          "user" => %{"_aj_globalid" => "gid://myapp/User/123"},
          "action" => "process"
        }
      ]

      normalized = Deserializer.normalize_args_for_elixir(TestJob, args, %{})
      assert is_map(normalized)

      user = Map.get(normalized, "user") || Map.get(normalized, :user)
      assert %{__struct__: :global_id, app: "myapp", model: "User", id: "123"} = user
    end
  end
end
