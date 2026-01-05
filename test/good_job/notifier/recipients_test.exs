defmodule GoodJob.Notifier.RecipientsTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "add_recipient/1 and remove_recipient/1" do
    test "add_recipient when notifier not started returns ok" do
      # Stop notifier if running
      if pid = Process.whereis(Notifier) do
        try do
          GenServer.call(pid, :shutdown, 1000)
        rescue
          _ -> GenServer.stop(pid, :normal, 1000)
        end

        Process.sleep(100)
      end

      result = Notifier.add_recipient(self())
      assert result == :ok
    end

    test "remove_recipient when notifier not started returns ok" do
      # Stop notifier if running
      if pid = Process.whereis(Notifier) do
        try do
          GenServer.call(pid, :shutdown, 1000)
        rescue
          _ -> GenServer.stop(pid, :normal, 1000)
        end

        Process.sleep(100)
      end

      result = Notifier.remove_recipient(self())
      assert result == :ok
    end
  end
end
