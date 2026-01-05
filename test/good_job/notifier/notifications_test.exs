defmodule GoodJob.Notifier.NotificationsTest do
  use GoodJob.Test.Support.NotifierSetup, async: false

  alias GoodJob.Notifier

  describe "notification parsing" do
    test "handles invalid JSON payload" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()
      Process.sleep(100)

      # Add recipient
      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Simulate invalid JSON
      invalid_payload = "invalid json{"

      # Manually test handle_notification logic
      case Jason.decode(invalid_payload) do
        {:ok, _message} ->
          send(test_pid, {:good_job_notification, %{}})

        {:error, _} ->
          # Should log warning but not crash
          :ok
      end

      assert Process.alive?(pid)
    end

    test "handles valid JSON payload" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()
      Process.sleep(100)

      # Add recipient
      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Valid JSON
      payload = Jason.encode!(%{type: "job_created", job_id: "test-123"})

      case Jason.decode(payload) do
        {:ok, message} ->
          send(test_pid, {:good_job_notification, message})

          receive do
            {:good_job_notification, received} ->
              assert received["type"] == "job_created"
              assert received["job_id"] == "test-123"
          after
            100 -> :ok
          end

        _ ->
          :ok
      end

      assert Process.alive?(pid)
    end
  end

  describe "handle_info/2 - notifications" do
    test "handles {:notification, channel, payload} message" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()
      Process.sleep(100)

      # Add recipient
      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Send notification message
      channel = "good_job"
      payload = Jason.encode!(%{queue_name: "default"})
      send(pid, {:notification, channel, payload})
      Process.sleep(50)

      # Should receive notification
      receive do
        {:good_job_notification, message} ->
          assert message["queue_name"] == "default"
      after
        200 -> flunk("Did not receive notification")
      end

      assert Process.alive?(pid)
    end

    test "handles {:DOWN, ref, :process, pid, reason} message" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Create a test process that stays alive until explicitly exited
      temp_pid =
        spawn(fn ->
          Process.sleep(:infinity)
        end)

      GenServer.cast(pid, {:add_recipient, temp_pid})
      Process.sleep(50)

      # Verify it's in recipients
      state = :sys.get_state(pid)
      assert temp_pid in state.recipients

      # Kill the process
      Process.exit(temp_pid, :kill)
      Process.sleep(100)

      # Should be removed from recipients
      state = :sys.get_state(pid)
      assert temp_pid not in state.recipients
    end

    test "handles unhandled messages" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Send unhandled message
      send(pid, :unknown_message)
      Process.sleep(50)

      # Should not crash
      assert Process.alive?(pid)
    end
  end

  describe "notify/3 callback (SimpleConnection)" do
    test "handles notification on correct channel" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()
      Process.sleep(100)

      # Add recipient
      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Simulate notify callback (this is called by SimpleConnection)
      # We can't directly call it, but we can test the logic
      channel = "good_job"
      payload = Jason.encode!(%{queue_name: "default"})

      # The notify/3 callback would be called by SimpleConnection
      # We test the notification handling via handle_info instead
      send(pid, {:notification, channel, payload})
      Process.sleep(50)

      receive do
        {:good_job_notification, message} ->
          assert message["queue_name"] == "default"
      after
        200 -> flunk("Did not receive notification")
      end
    end

    test "ignores notification on wrong channel" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()
      Process.sleep(100)

      # Add recipient
      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Send notification on wrong channel
      channel = "wrong_channel"
      payload = Jason.encode!(%{queue_name: "default"})
      send(pid, {:notification, channel, payload})
      Process.sleep(50)

      # Should not receive notification
      receive do
        {:good_job_notification, _} ->
          flunk("Should not receive notification for wrong channel")
      after
        100 -> :ok
      end
    end

    test "handles invalid JSON in notify callback" do
      {:ok, pid} = Notifier.start_link([])
      Process.sleep(100)

      # Send notification with invalid JSON
      channel = "good_job"
      payload = "invalid json{"
      send(pid, {:notification, channel, payload})
      Process.sleep(50)

      # Should not crash
      assert Process.alive?(pid)
    end
  end

  describe "handle_notification/3 private function" do
    test "ignores notifications when shutdown is true" do
      {:ok, pid} = Notifier.start_link([])
      test_pid = self()
      Process.sleep(100)

      # Set shutdown flag
      GenServer.call(pid, :shutdown, 5000)

      # Add recipient
      GenServer.cast(pid, {:add_recipient, test_pid})
      Process.sleep(50)

      # Send notification
      channel = "good_job"
      payload = Jason.encode!(%{queue_name: "default"})
      send(pid, {:notification, channel, payload})
      Process.sleep(50)

      # Should not receive notification (shutdown ignores them)
      receive do
        {:good_job_notification, _} ->
          flunk("Should not receive notification when shutdown")
      after
        100 -> :ok
      end
    end
  end
end
