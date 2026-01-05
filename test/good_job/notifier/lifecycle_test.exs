defmodule GoodJob.Notifier.LifecycleTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "start_link/1" do
    test "starts the notifier process" do
      {:ok, pid} = Notifier.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)

      try do
        GenServer.call(pid, :shutdown, 1000)
      rescue
        _ -> GenServer.stop(pid, :normal, 1000)
      end
    end
  end

  describe "notify/1" do
    test "sends notify message to notifier" do
      {:ok, _pid} = Notifier.start_link([])
      # Allow init to complete
      Process.sleep(100)

      result = Notifier.notify(%{type: "test"})
      assert result == :ok
    end
  end

  describe "init/1" do
    test "initializes with correct state structure when listen_notify disabled" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      state = :sys.get_state(pid)
      assert state.connected? == false
      assert state.listening? == false
      assert is_list(state.recipients)
      assert is_integer(state.connection_errors)
      assert is_boolean(state.connection_errors_reported)
      assert is_boolean(state.shutdown)
      assert state.last_keepalive == nil
    end
  end

  describe "child_spec/1" do
    test "returns correct child specification" do
      spec = Notifier.child_spec([])
      assert spec.id == Notifier
      assert spec.start == {Notifier, :start_link, [[]]}
      assert spec.type == :worker
      assert spec.restart == :permanent
      assert spec.shutdown == 5000
    end
  end
end
