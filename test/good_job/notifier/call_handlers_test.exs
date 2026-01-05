defmodule GoodJob.Notifier.CallHandlersTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "handle_call/2" do
    test "shutdown returns ok and sets shutdown flag" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      result = GenServer.call(pid, :shutdown, 5000)
      assert result == :ok

      shutdown? = GenServer.call(pid, :shutdown?, 5000)
      assert shutdown? == true
    end

    test "shutdown? returns false when not shutting down" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      shutdown? = GenServer.call(pid, :shutdown?, 5000)
      assert shutdown? == false
    end
  end
end
