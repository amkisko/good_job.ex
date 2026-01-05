defmodule GoodJob.ProcessTracker do
  @moduledoc """
  Tracks GoodJob processes in the database for advisory lock management.

  This module maintains a record in the `good_job_processes` table
  that is used to identify the process for advisory locks.
  """

  use GenServer
  require Logger

  alias GoodJob.Process, as: ProcessSchema
  alias GoodJob.Repo
  alias GoodJob.Telemetry

  @refresh_interval 30_000

  @doc """
  Starts the process tracker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the process ID for advisory locks.
  """
  def id_for_lock do
    GenServer.call(__MODULE__, :id_for_lock)
  end

  @impl true
  def init(_opts) do
    process_id = Ecto.UUID.generate()

    # Schedule refresh (but don't create record until needed)
    schedule_refresh()

    {:ok, %{process_id: process_id, record_id: nil, locks: 0}}
  end

  @impl true
  def handle_call(:id_for_lock, _from, state) do
    state = %{state | locks: state.locks + 1}

    # Ensure record exists if we have locks
    record_id =
      if state.locks > 0 and is_nil(state.record_id) do
        create_or_update_record(state.process_id)
      else
        state.record_id
      end

    {:reply, record_id || state.process_id, %{state | record_id: record_id}}
  end

  @impl true
  def handle_info(:refresh, state) do
    if state.locks > 0 and state.record_id do
      refresh_record(state.record_id)
      # Emit heartbeat telemetry
      Telemetry.process_heartbeat(state.process_id)
    end

    schedule_refresh()
    {:noreply, state}
  end

  defp create_or_update_record(process_id) do
    repo = Repo.repo()

    case repo.get(ProcessSchema, process_id) do
      nil ->
        %ProcessSchema{id: process_id}
        |> ProcessSchema.changeset(%{state: %{}, lock_type: 0})
        |> repo.insert!()
        |> Map.get(:id)

      record ->
        # Update timestamp
        record
        |> ProcessSchema.changeset(%{})
        |> repo.update!()
        |> Map.get(:id)
    end
  rescue
    e ->
      # Repo not ready yet, return nil and try again later
      msg = Exception.message(e)

      if String.contains?(msg, "not started") or String.contains?(msg, "does not exist") or
           String.contains?(msg, "ownership") do
        nil
      else
        reraise e, __STACKTRACE__
      end
  end

  defp refresh_record(record_id) do
    repo = Repo.repo()

    case repo.get(ProcessSchema, record_id) do
      nil ->
        :ok

      record ->
        record
        |> ProcessSchema.changeset(%{})
        |> repo.update!()

        :ok
    end
  rescue
    e ->
      # Repo not ready or record doesn't exist, ignore
      msg = Exception.message(e)

      if String.contains?(msg, "not started") or String.contains?(msg, "does not exist") or
           String.contains?(msg, "ownership") do
        :ok
      else
        reraise e, __STACKTRACE__
      end
  end

  defp schedule_refresh do
    :erlang.send_after(@refresh_interval, self(), :refresh)
  end
end
