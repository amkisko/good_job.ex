defmodule GoodJob.Notifier.CastHandlersTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "handle_cast/2" do
    test "adds recipient" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()

      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Verify recipient was added by checking state
      state = :sys.get_state(pid)
      assert test_pid in state.recipients
    end

    test "removes recipient" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()

      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      GenServer.cast(pid, {:remove_recipient, test_pid})
      Process.sleep(50)

      state = :sys.get_state(pid)
      assert test_pid not in state.recipients
    end

    test "notify when not connected logs warning" do
      {:ok, pid} = Notifier.start_link([])
      # Don't wait for connection

      GenServer.cast(pid, {:notify, %{type: "test"}})
      Process.sleep(50)

      # Should not crash
      assert Process.alive?(pid)
    end

    test "notify when connected" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Set connected state
      :sys.replace_state(pid, fn state ->
        # Mock connection
        %{state | connected?: true}
      end)

      GenServer.cast(pid, {:notify, %{type: "test"}})
      Process.sleep(50)

      # Should not crash
      assert Process.alive?(pid)
    end
  end
end
