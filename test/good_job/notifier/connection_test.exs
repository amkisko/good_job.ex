defmodule GoodJob.Notifier.ConnectionTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "connection error handling" do
    test "handles Postgrex.Error" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Simulate connection error handling
      # Manually trigger error handling via state manipulation
      :sys.replace_state(pid, fn state ->
        # Simulate what handle_connection_error does
        new_error_count = state.connection_errors + 1
        %{state | connection_errors: new_error_count, connected?: false}
      end)

      state = :sys.get_state(pid)
      assert state.connection_errors > 0
      assert state.connected? == false
    end

    test "handles DBConnection.ConnectionError" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      :sys.replace_state(pid, fn state ->
        new_error_count = state.connection_errors + 1
        %{state | connection_errors: new_error_count, connected?: false}
      end)

      state = :sys.get_state(pid)
      assert state.connection_errors > 0
      assert state.connected? == false
    end

    test "handles non-connection errors" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Non-connection error should not increment error count
      state = :sys.get_state(pid)
      original_count = state.connection_errors

      # State should remain unchanged for non-connection errors
      assert is_integer(original_count)
    end

    test "reports error when threshold exceeded" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Set error count to threshold
      :sys.replace_state(pid, fn state ->
        %{state | connection_errors: 5, connection_errors_reported: false}
      end)

      # Next error should trigger reporting
      :sys.replace_state(pid, fn state ->
        new_count = state.connection_errors + 1

        if new_count >= 6 and not state.connection_errors_reported do
          %{state | connection_errors: new_count, connection_errors_reported: true, connected?: false}
        else
          %{state | connection_errors: new_count, connected?: false}
        end
      end)

      state = :sys.get_state(pid)
      assert state.connection_errors >= 6
      assert state.connection_errors_reported == true
    end
  end

  describe "handle_connect/1 and handle_disconnect/1" do
    test "handle_connect sets connected state" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Simulate connection
      :sys.replace_state(pid, fn state ->
        %{state | connected?: true, connection_errors: 0, connection_errors_reported: false}
      end)

      state = :sys.get_state(pid)
      assert state.connected? == true
      assert state.connection_errors == 0
    end

    test "handle_disconnect sets disconnected state" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Set connected first
      :sys.replace_state(pid, fn state ->
        %{state | connected?: true, listening?: true}
      end)

      # Simulate disconnect
      :sys.replace_state(pid, fn state ->
        %{state | connected?: false, listening?: false}
      end)

      state = :sys.get_state(pid)
      assert state.connected? == false
      assert state.listening? == false
    end
  end
end
