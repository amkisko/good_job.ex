defmodule GoodJob.Plugins.PrunerTest do
  use ExUnit.Case, async: false

  alias GoodJob.{Config, Plugins.Pruner}

  describe "validate/1" do
    test "returns ok for valid options" do
      assert Pruner.validate(max_age: 3600, max_count: 1000, interval: 300) == :ok
    end

    test "returns error for invalid max_age" do
      assert {:error, _} = Pruner.validate(max_age: "invalid")
    end

    test "returns error for invalid max_count" do
      assert {:error, _} = Pruner.validate(max_count: "invalid")
    end

    test "returns error for invalid interval" do
      assert {:error, _} = Pruner.validate(interval: "invalid")
    end

    test "returns ok for empty options" do
      assert Pruner.validate([]) == :ok
    end
  end

  describe "start_link/1" do
    test "starts pruner with default options" do
      conf = Config.config()
      assert {:ok, pid} = Pruner.start_link(conf: conf, name: :test_pruner)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts pruner with custom options" do
      conf = Config.config()

      assert {:ok, pid} =
               Pruner.start_link(
                 conf: conf,
                 max_age: 7200,
                 max_count: 5000,
                 interval: 300,
                 name: :test_pruner_custom
               )

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
