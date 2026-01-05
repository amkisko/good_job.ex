defmodule GoodJob.CronManagerTest do
  use ExUnit.Case, async: false

  alias GoodJob.Cron.Entry
  alias GoodJob.CronManager

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  setup do
    # Clean up any existing cron entries
    :ok
  end

  describe "start_link/1" do
    test "starts with empty cron entries" do
      assert {:ok, pid} = CronManager.start_link(cron_entries: [], name: :test_cron_manager_1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "starts with valid cron entries" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      assert {:ok, pid} = CronManager.start_link(cron_entries: [entry], name: :test_cron_manager_2)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "raises for duplicate keys" do
      entry1 = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      entry2 = Entry.new(key: "test", cron: "1 * * * *", class: TestJob)

      # When init/1 raises, the GenServer process exits and the exception propagates
      # We need to catch the exit to test this properly
      Process.flag(:trap_exit, true)

      result =
        try do
          CronManager.start_link(cron_entries: [entry1, entry2], name: :test_cron_manager_3)
        catch
          :exit, {{:error, {error, _stacktrace}}, _pid} ->
            {:error, {error, []}}

          :exit, {error, _pid} when is_exception(error) ->
            {:error, {error, []}}
        end

      Process.flag(:trap_exit, false)

      # Verify the error format
      assert {:error, {error, _stacktrace}} = result
      assert %ArgumentError{} = error
      assert error.message =~ "Duplicate cron entry keys found"
      assert error.message =~ "test"
    end
  end

  describe "handle_info/2" do
    test "handles :start message when running is false" do
      {:ok, pid} = CronManager.start_link(cron_entries: [], name: :test_cron_manager_4)
      # Send shutdown first to set running to false
      GenServer.call(pid, :shutdown)
      # Now send :start - should not start
      send(pid, :start)
      Process.sleep(50)
      assert GenServer.call(pid, :shutdown?) == true
      GenServer.stop(pid)
    end

    test "handles :start message and schedules entries" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      {:ok, pid} = CronManager.start_link(cron_entries: [entry], name: :test_cron_manager_5)
      # Wait for :start message to be processed
      Process.sleep(150)
      # Verify it's running (running should be true after :start is processed)
      assert GenServer.call(pid, :shutdown?) == false
      GenServer.stop(pid)
    end

    test "handles :cron_tick with valid entry" do
      entry = Entry.new(key: "test", cron: "* * * * *", class: TestJob)
      {:ok, pid} = CronManager.start_link(cron_entries: [entry], name: :test_cron_manager_6)
      Process.sleep(100)
      # Send cron tick
      send(pid, {:cron_tick, "test"})
      Process.sleep(100)
      GenServer.stop(pid)
    end

    test "handles :cron_tick with non-existent entry" do
      {:ok, pid} = CronManager.start_link(cron_entries: [], name: :test_cron_manager_7)
      # Send cron tick for non-existent entry
      send(pid, {:cron_tick, "nonexistent"})
      Process.sleep(50)
      GenServer.stop(pid)
    end

    test "handles :cron_tick when too early (reschedules)" do
      # Create a cron that runs in the future
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)
      cron = "#{future_time.minute} #{future_time.hour} * * *"
      entry = Entry.new(key: "future", cron: cron, class: TestJob)
      {:ok, pid} = CronManager.start_link(cron_entries: [entry], name: :test_cron_manager_8)
      Process.sleep(100)
      # Send cron tick - should reschedule
      send(pid, {:cron_tick, "future"})
      Process.sleep(100)
      GenServer.stop(pid)
    end
  end

  describe "handle_call/3" do
    test "shutdown cancels all tasks" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      {:ok, pid} = CronManager.start_link(cron_entries: [entry], name: :test_cron_manager_9)
      Process.sleep(100)
      assert GenServer.call(pid, :shutdown) == :ok
      assert GenServer.call(pid, :shutdown?) == true
      GenServer.stop(pid)
    end

    test "shutdown? returns true when not running" do
      {:ok, pid} = CronManager.start_link(cron_entries: [], name: :test_cron_manager_10)
      GenServer.call(pid, :shutdown)
      assert GenServer.call(pid, :shutdown?) == true
      GenServer.stop(pid)
    end

    test "shutdown? returns false when running" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      {:ok, pid} = CronManager.start_link(cron_entries: [entry], name: :test_cron_manager_11)
      Process.sleep(100)
      assert GenServer.call(pid, :shutdown?) == false
      GenServer.stop(pid)
    end
  end

  describe "graceful restart" do
    test "creates graceful tasks when graceful_restart_period is set" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)

      {:ok, pid} =
        CronManager.start_link(
          cron_entries: [entry],
          graceful_restart_period: 3600,
          name: :test_cron_manager_12
        )

      Process.sleep(100)
      GenServer.stop(pid)
    end

    test "does not create graceful tasks when graceful_restart_period is nil" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)

      {:ok, pid} =
        CronManager.start_link(
          cron_entries: [entry],
          graceful_restart_period: nil,
          name: :test_cron_manager_13
        )

      Process.sleep(100)
      GenServer.stop(pid)
    end
  end

  describe "validate_entries/1" do
    test "raises for invalid entry" do
      Process.flag(:trap_exit, true)

      result =
        try do
          CronManager.start_link(cron_entries: [%{invalid: "entry"}], name: :test_cron_manager_14)
        catch
          :exit, {{:error, {error, _stacktrace}}, _pid} ->
            {:error, {error, []}}

          :exit, {error, _pid} when is_exception(error) ->
            {:error, {error, []}}
        end

      Process.flag(:trap_exit, false)

      assert {:error, {error, _stacktrace}} = result
      assert %ArgumentError{} = error
      assert error.message =~ "Invalid cron entry"
    end
  end
end
