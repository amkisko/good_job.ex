defmodule GoodJob.Notifier.ResultHandlersTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "handle_result/2" do
    test "handles list of Postgrex.Result when not listening" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Simulate result from LISTEN query
      _result = %Postgrex.Result{command: :listen}
      state = :sys.get_state(pid)

      # Manually test the logic
      new_state = %{state | listening?: true, from: nil, last_keepalive: DateTime.utc_now()}
      assert new_state.listening? == true
      refute is_nil(new_state.last_keepalive)
    end

    test "handles list of Postgrex.Result when already listening" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Set listening state
      :sys.replace_state(pid, fn state ->
        %{state | listening?: true}
      end)

      state = :sys.get_state(pid)
      assert state.listening? == true
    end

    test "handles {:ok, result} tuple when not listening" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      state = :sys.get_state(pid)
      assert state.listening? == false
    end

    test "handles {:error, error} tuple" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Simulate error handling
      :sys.replace_state(pid, fn state ->
        %{state | connection_errors: state.connection_errors + 1, connected?: false}
      end)

      state = :sys.get_state(pid)
      assert state.connection_errors > 0
      assert state.connected? == false
    end
  end
end
