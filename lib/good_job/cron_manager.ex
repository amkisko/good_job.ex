defmodule GoodJob.CronManager do
  @moduledoc """
  Manages cron-like scheduled jobs.

  This module enqueues jobs based on cron expressions.
  """

  use GenServer
  require Logger

  alias GoodJob.{Cron.Entry, Telemetry}

  @doc """
  Starts the cron manager.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    cron_entries = Keyword.get(opts, :cron_entries, [])
    graceful_restart_period = Keyword.get(opts, :graceful_restart_period)

    # Validate all cron entries
    validated_entries = validate_entries(cron_entries)

    # Check for duplicate keys
    keys = Enum.map(validated_entries, & &1.key)

    if length(keys) != length(Enum.uniq(keys)) do
      duplicates = keys -- Enum.uniq(keys)

      raise ArgumentError,
            "Duplicate cron entry keys found: #{inspect(Enum.uniq(duplicates))}"
    end

    state = %{
      cron_entries: validated_entries,
      tasks: %{},
      running: false,
      shutdown: false,
      graceful_restart_period: graceful_restart_period
    }

    # Store cron entries in persistent_term for runtime access
    if not Enum.empty?(validated_entries) do
      Enum.each(validated_entries, fn entry ->
        :persistent_term.put({:good_job, :cron_entry, entry.key}, entry)
      end)
    end

    # Start scheduling if entries are provided
    if not Enum.empty?(validated_entries) do
      send(self(), :start)
    end

    {:ok, state}
  end

  defp validate_entries(entries) do
    Enum.map(entries, fn entry ->
      # Entry should already be validated in Entry.new, but double-check
      if is_struct(entry, Entry) do
        entry
      else
        raise ArgumentError, "Invalid cron entry: #{inspect(entry)}"
      end
    end)
  end

  @impl true
  def handle_info(:start, %{running: false, tasks: tasks} = state) when map_size(tasks) == 0 do
    # Initial state or explicitly shut down - start if we have entries
    if Enum.empty?(state.cron_entries) do
      {:noreply, state}
    else
      state = %{state | running: true}
      # Schedule all cron entries
      state =
        Enum.reduce(state.cron_entries, state, fn entry, acc ->
          acc = create_task(entry, acc)
          # Only create graceful tasks if graceful_restart_period is set
          # and wrap in try/rescue in case database isn't available (e.g., in tests)
          if acc.graceful_restart_period do
            try do
              create_graceful_tasks(entry, acc)
            rescue
              _ -> :ok
            end
          end

          acc
        end)

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:start, state) do
    # Already running, ignore
    {:noreply, state}

    # Schedule all cron entries
    state =
      Enum.reduce(state.cron_entries, state, fn entry, acc ->
        acc = create_task(entry, acc)
        # create_graceful_tasks may fail if database isn't available (e.g., in tests)
        try do
          create_graceful_tasks(entry, acc)
        rescue
          _ -> :ok
        end

        acc
      end)

    Telemetry.cron_manager_start(state.cron_entries)
    {:noreply, state}
  end

  @impl true
  def handle_info({:cron_tick, entry_key}, state) do
    # Find entry by key
    entry = Enum.find(state.cron_entries, &(&1.key == entry_key))

    case entry do
      nil ->
        {:noreply, state}

      entry ->
        now = DateTime.utc_now()
        cron_at = Entry.next_at(entry, now)

        # Check if it's time to run (handle clock drift)
        if DateTime.compare(cron_at, now) == :gt do
          # Too early, reschedule
          state = create_task(entry, state)
          {:noreply, state}
        else
          # Re-schedule the next occurrence before enqueueing
          state = create_task(entry, state)

          # Enqueue the job
          case Entry.enqueue(entry, cron_at) do
            {:ok, _} ->
              Telemetry.cron_job_enqueued(entry, cron_at)

            {:error, error} ->
              Logger.error("Failed to enqueue cron job #{entry.key}: #{inspect(error)}")
          end

          {:noreply, state}
        end
    end
  end

  defp create_task(entry, state) do
    now = DateTime.utc_now()
    next_at = Entry.next_at(entry, now)

    # Calculate delay in milliseconds
    delay_ms = DateTime.diff(next_at, now, :millisecond)

    # Ensure minimum delay (at least 100ms to avoid immediate execution)
    delay_ms = max(delay_ms, 100)

    # Cancel existing task if any
    if ref = Map.get(state.tasks, entry.key) do
      Process.cancel_timer(ref)
    end

    # Schedule the task
    ref = Process.send_after(self(), {:cron_tick, entry.key}, delay_ms)

    # Store the task reference
    tasks = Map.put(state.tasks, entry.key, ref)
    %{state | tasks: tasks}
  end

  defp create_graceful_tasks(entry, state) do
    case state.graceful_restart_period do
      nil ->
        :ok

      period when is_integer(period) ->
        now = DateTime.utc_now()
        start_time = DateTime.add(now, -period, :second)

        # Calculate all cron times within the period
        # We iterate by finding the next cron time until we exceed the period
        cron_times =
          Stream.unfold(start_time, fn current_time ->
            if DateTime.compare(current_time, now) == :lt do
              next_time = Entry.next_at(entry, current_time)

              if DateTime.compare(next_time, now) != :gt do
                {next_time, next_time}
              else
                nil
              end
            else
              nil
            end
          end)
          |> Enum.to_list()

        Enum.each(cron_times, fn cron_at ->
          Entry.enqueue(entry, cron_at)
        end)

      _ ->
        :ok
    end
  end

  @impl true
  def handle_call(:shutdown, _from, state) do
    # Cancel all scheduled tasks
    Enum.each(state.tasks, fn {_key, ref} ->
      Process.cancel_timer(ref)
    end)

    {:reply, :ok, %{state | running: false, shutdown: true, tasks: %{}}}
  end

  @impl true
  def handle_call(:shutdown?, _from, state) do
    {:reply, not state.running, state}
  end
end
