defmodule GoodJob.PluginsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Plugin

  defmodule TestPlugin do
    @behaviour Plugin

    use GenServer

    @impl Plugin
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: opts[:name])
    end

    def start(opts) do
      GenServer.start(__MODULE__, opts, name: opts[:name])
    end

    @impl Plugin
    def validate(opts) do
      if Keyword.has_key?(opts, :mode) do
        :ok
      else
        {:error, "expected opts to have a :mode key"}
      end
    end

    @impl GenServer
    def init(opts) do
      case validate(opts) do
        :ok -> {:ok, opts}
        {:error, reason} -> {:stop, reason}
      end
    end
  end

  describe "Plugin behaviour" do
    test "validates plugin options" do
      assert TestPlugin.validate(mode: :test) == :ok
      assert TestPlugin.validate([]) == {:error, "expected opts to have a :mode key"}
    end

    test "can start plugin" do
      {:ok, pid} = TestPlugin.start_link(name: TestPlugin, mode: :test)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "stops on validation failure" do
      # Plugin stops with reason when validation fails
      # GenServer.init/1 returns {:stop, reason} which causes start/start_link to return {:error, reason}
      # Using start instead of start_link to avoid exit signal propagation
      result = TestPlugin.start(name: TestPlugin)
      # start returns {:error, reason} when init returns {:stop, reason}
      assert result == {:error, "expected opts to have a :mode key"}
    end
  end
end
