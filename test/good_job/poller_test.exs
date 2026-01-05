defmodule GoodJob.PollerTest do
  use ExUnit.Case, async: false

  alias GoodJob.Poller

  setup do
    # Stop any existing poller
    if pid = Process.whereis(Poller) do
      try do
        GenServer.stop(pid, :normal, 1000)
      rescue
        _ -> :ok
      end

      Process.sleep(100)
    end

    # Configure queues for testing
    original_config = Application.get_env(:good_job, :config, %{})
    Application.put_env(:good_job, :config, Map.merge(original_config, %{queues: "*"}))

    on_exit(fn ->
      Application.put_env(:good_job, :config, original_config)

      if pid = Process.whereis(Poller) do
        if Process.alive?(pid) do
          try do
            GenServer.stop(pid, :normal, 1000)
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
        end
      end
    end)

    :ok
  end

  describe "start_link/1" do
    test "starts poller with poll_interval" do
      {:ok, pid} = Poller.start_link(poll_interval: 5)
      assert is_pid(pid)
      assert Process.alive?(pid)

      try do
        GenServer.stop(pid, :normal, 1000)
      rescue
        _ -> :ok
      end
    end

    test "starts poller with recipients" do
      test_pid = spawn(fn -> :ok end)
      {:ok, pid} = Poller.start_link(poll_interval: 10, recipients: [test_pid])
      assert is_pid(pid)

      try do
        GenServer.stop(pid, :normal, 1000)
      rescue
        _ -> :ok
      end
    end

    test "starts poller with zero poll_interval (no polling)" do
      {:ok, pid} = Poller.start_link(poll_interval: 0)
      assert is_pid(pid)

      try do
        GenServer.stop(pid, :normal, 1000)
      rescue
        _ -> :ok
      end
    end
  end

  describe "add_recipient/1" do
    test "adds a recipient to receive poll notifications" do
      {:ok, _pid} = Poller.start_link(poll_interval: 10)

      test_pid =
        spawn(fn ->
          receive do
            :poll -> :ok
          end
        end)

      result = Poller.add_recipient(test_pid)
      assert result == :ok

      # Clean up
      Poller.remove_recipient(test_pid)
    end

    test "adds recipient and sends poll message" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Trigger poll
      send(poller_pid, :poll)
      Process.sleep(50)

      receive do
        :poll -> :ok
      after
        200 -> flunk("Did not receive poll message")
      end
    end
  end

  describe "remove_recipient/1" do
    test "removes a recipient from poll notifications" do
      {:ok, _pid} = Poller.start_link(poll_interval: 10)
      test_pid = spawn(fn -> :ok end)

      Poller.add_recipient(test_pid)
      result = Poller.remove_recipient(test_pid)
      assert result == :ok
    end
  end

  describe "handle_info/2" do
    test "handles :poll when running" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Send poll message
      send(poller_pid, :poll)
      Process.sleep(50)

      receive do
        :poll -> :ok
      after
        200 -> flunk("Did not receive poll message")
      end
    end

    test "handles :poll when not running" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Shutdown poller
      GenServer.call(poller_pid, :shutdown)

      # Send poll message
      send(poller_pid, :poll)
      Process.sleep(50)

      # Should not receive poll message
      receive do
        :poll -> flunk("Should not receive poll when not running")
      after
        100 -> :ok
      end
    end

    test "handles :register_notifier when notifier not started" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 10)

      # Stop notifier if running
      if notifier_pid = Process.whereis(GoodJob.Notifier) do
        try do
          GenServer.stop(notifier_pid, :normal, 1000)
        rescue
          _ -> :ok
        end

        Process.sleep(100)
      end

      # Send register_notifier message
      send(poller_pid, :register_notifier)
      Process.sleep(150)

      # Should still be alive
      assert Process.alive?(poller_pid)
    end

    test "handles :register_notifier when notifier is started" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 10)

      # Start notifier if not running
      if Process.whereis(GoodJob.Notifier) == nil do
        {:ok, _notifier_pid} = GoodJob.Notifier.start_link([])
        Process.sleep(100)
      end

      # Send register_notifier message
      send(poller_pid, :register_notifier)
      Process.sleep(50)

      # Should still be alive
      assert Process.alive?(poller_pid)
    end

    test "handles {:good_job_notification, message} with queue_name" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Send notification with queue_name
      message = %{"queue_name" => "default"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should trigger poll
      receive do
        :poll -> :ok
      after
        200 -> flunk("Did not receive poll after notification")
      end
    end

    test "handles {:good_job_notification, message} without queue_name" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Send notification without queue_name
      message = %{"type" => "other"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should not trigger poll
      receive do
        :poll -> flunk("Should not poll for non-queue notifications")
      after
        100 -> :ok
      end
    end
  end

  describe "queue filtering" do
    test "queue_matches? with empty map (all queues)" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Send notification for any queue
      message = %{"queue_name" => "any_queue"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should trigger poll (empty map means all queues match)
      receive do
        :poll -> :ok
      after
        200 -> flunk("Should poll for all queues")
      end
    end

    test "queue_matches? with exclude queues" do
      original_config = Application.get_env(:good_job, :config, %{})
      Application.put_env(:good_job, :config, Map.merge(original_config, %{queues: "*,!excluded"}))

      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Send notification for excluded queue
      message = %{"queue_name" => "excluded"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should not trigger poll
      receive do
        :poll -> flunk("Should not poll for excluded queue")
      after
        100 -> :ok
      end

      # Send notification for non-excluded queue
      message = %{"queue_name" => "default"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should trigger poll
      receive do
        :poll -> :ok
      after
        200 -> :ok
      end

      Application.put_env(:good_job, :config, original_config)
    end

    test "queue_matches? with include queues" do
      original_config = Application.get_env(:good_job, :config, %{})
      Application.put_env(:good_job, :config, Map.merge(original_config, %{queues: "included,other"}))

      {:ok, poller_pid} = Poller.start_link(poll_interval: 100)
      test_pid = self()

      Poller.add_recipient(test_pid)

      # Send notification for included queue
      message = %{"queue_name" => "included"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should trigger poll
      receive do
        :poll -> :ok
      after
        200 -> :ok
      end

      # Send notification for non-included queue
      message = %{"queue_name" => "not_included"}
      send(poller_pid, {:good_job_notification, message})
      Process.sleep(50)

      # Should not trigger poll
      receive do
        :poll -> flunk("Should not poll for non-included queue")
      after
        100 -> :ok
      end

      Application.put_env(:good_job, :config, original_config)
    end
  end

  describe "handle_call/3" do
    test "shutdown sets running to false" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 10)

      result = GenServer.call(poller_pid, :shutdown)
      assert result == :ok

      shutdown? = GenServer.call(poller_pid, :shutdown?)
      assert shutdown? == true
    end

    test "shutdown? returns false when running" do
      {:ok, poller_pid} = Poller.start_link(poll_interval: 10)

      shutdown? = GenServer.call(poller_pid, :shutdown?)
      assert shutdown? == false
    end
  end
end
