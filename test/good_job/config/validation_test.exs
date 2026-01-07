defmodule GoodJob.Config.ValidationTest do
  use ExUnit.Case, async: true

  alias GoodJob.Config.Validation

  # Base config with required fields
  @base_config %{
    repo: GoodJob.TestRepo,
    execution_mode: :async,
    max_processes: 5,
    poll_interval: 1
  }

  describe "validate!/1" do
    test "raises error when repo is missing" do
      config = Map.delete(@base_config, :repo)

      assert_raise RuntimeError, ~r/GoodJob repo not configured/, fn ->
        Validation.validate!(config)
      end
    end

    test "raises error when execution_mode is invalid" do
      config = Map.put(@base_config, :execution_mode, :unknown)

      assert_raise ArgumentError, ~r/execution_mode must be one of/, fn ->
        Validation.validate!(config)
      end
    end

    test "raises error when max_processes is invalid" do
      config = Map.put(@base_config, :max_processes, 0)

      assert_raise ArgumentError, ~r/max_processes must be a positive integer/, fn ->
        Validation.validate!(config)
      end
    end

    test "raises error when plugins contain unavailable module" do
      config = Map.put(@base_config, :plugins, [{NonExistentPlugin, []}])

      assert_raise ArgumentError, ~r/plugin module/, fn ->
        Validation.validate!(config)
      end
    end

    test "validates external_jobs is a map" do
      config = Map.put(@base_config, :external_jobs, %{"External::Job" => MyApp.Job})

      # Should not raise, returns config
      result = Validation.validate!(config)
      assert is_map(result)
      assert result.external_jobs == %{"External::Job" => MyApp.Job}
    end

    test "raises error when external_jobs is not a map" do
      config = Map.put(@base_config, :external_jobs, "not a map")

      assert_raise ArgumentError, ~r/GoodJob external_jobs must be a map/, fn ->
        Validation.validate!(config)
      end
    end

    test "raises error when external_jobs keys are not strings" do
      config = Map.put(@base_config, :external_jobs, %{:"External::Job" => MyApp.Job})

      assert_raise ArgumentError, ~r/GoodJob external_jobs keys must be strings/, fn ->
        Validation.validate!(config)
      end
    end

    test "raises error when external_jobs values are not atoms" do
      config = Map.put(@base_config, :external_jobs, %{"External::Job" => "MyApp.Job"})

      assert_raise ArgumentError, ~r/GoodJob external_jobs values must be atoms/, fn ->
        Validation.validate!(config)
      end
    end

    test "validates empty external_jobs map" do
      config = Map.put(@base_config, :external_jobs, %{})

      # Should not raise, returns config
      result = Validation.validate!(config)
      assert is_map(result)
      assert result.external_jobs == %{}
    end

    test "validates external_jobs with multiple mappings" do
      config =
        Map.put(@base_config, :external_jobs, %{
          "External::Job1" => MyApp.Job1,
          "External::Job2" => MyApp.Job2
        })

      # Should not raise, returns config
      result = Validation.validate!(config)
      assert is_map(result)
      assert result.external_jobs == %{"External::Job1" => MyApp.Job1, "External::Job2" => MyApp.Job2}
    end

    test "handles nil external_jobs" do
      config = Map.put(@base_config, :external_jobs, nil)

      # nil should be allowed (means not configured), returns config
      result = Validation.validate!(config)
      assert is_map(result)
      assert result.external_jobs == nil
    end

    test "handles missing external_jobs key" do
      config = @base_config

      # Should not raise when key is missing, returns config
      result = Validation.validate!(config)
      assert is_map(result)
      refute Map.has_key?(result, :external_jobs)
    end
  end
end
