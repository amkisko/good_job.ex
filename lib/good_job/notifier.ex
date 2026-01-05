defmodule GoodJob.Notifier do
  @moduledoc """
  Handles PostgreSQL LISTEN/NOTIFY for low-latency job dispatch.

  This module listens on the `good_job` channel (matching Ruby GoodJob's CHANNEL constant)
  and notifies schedulers when new jobs are available.

  The channel name defaults to `"good_job"` and can be configured via `:notifier_channel`
  in GoodJob configuration. This must match the channel used by Ruby GoodJob for
  cross-language compatibility.

  Uses `Postgrex.SimpleConnection` for connection management.
  """

  require Logger

  alias GoodJob.{Config, Repo, Telemetry}
  alias Postgrex.SimpleConnection, as: Simple

  @connection_error_threshold 6

  defstruct [
    :conf,
    :from,
    connected?: false,
    listening?: false,
    recipients: [],
    connection_errors: 0,
    connection_errors_reported: false,
    last_keepalive: nil,
    shutdown: false
  ]

  defp channel, do: Config.notifier_channel()

  @doc """
  Returns a child specification for the notifier.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Starts the notifier.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)

    state = %__MODULE__{
      conf: %{},
      connected?: false,
      listening?: false,
      recipients: [],
      connection_errors: 0,
      connection_errors_reported: false,
      last_keepalive: nil,
      shutdown: false
    }

    if Config.enable_listen_notify?() do
      repo = Repo.repo()
      config = repo.config()

      conn_opts =
        config
        |> Keyword.put(:name, name)
        |> Keyword.put_new(:auto_reconnect, true)
        |> Keyword.put_new(:sync_connect, false)

      Simple.start_link(__MODULE__, state, conn_opts)
    else
      # If LISTEN/NOTIFY is disabled, start a simple GenServer that does nothing
      GenServer.start_link(__MODULE__, state, name: name)
    end
  end

  @doc """
  Sends a NOTIFY message to PostgreSQL.
  """
  def notify(message) do
    if Config.enable_listen_notify?() do
      channel_name = channel()
      payload = Jason.encode!(message)

      Repo.repo().query(
        "SELECT pg_notify($1, $2)",
        [channel_name, payload]
      )

      :ok
    else
      :ok
    end
  end

  @doc """
  Adds a recipient to receive notifications.
  """
  def add_recipient(recipient) do
    if Config.enable_listen_notify?() do
      # Use Simple.call for SimpleConnection
      case Process.whereis(__MODULE__) do
        nil ->
          :ok

        pid ->
          Simple.call(pid, {:add_recipient, recipient})
      end
    else
      # Use GenServer.cast for regular GenServer
      GenServer.cast(__MODULE__, {:add_recipient, recipient})
    end
  end

  @doc """
  Removes a recipient from notifications.
  """
  def remove_recipient(recipient) do
    if Config.enable_listen_notify?() do
      # Use Simple.call for SimpleConnection
      case Process.whereis(__MODULE__) do
        nil ->
          :ok

        pid ->
          Simple.call(pid, {:remove_recipient, recipient})
      end
    else
      # Use GenServer.cast for regular GenServer
      GenServer.cast(__MODULE__, {:remove_recipient, recipient})
    end
  end

  # Postgrex.SimpleConnection and GenServer callbacks
  # These work for both SimpleConnection (when LISTEN/NOTIFY enabled) and GenServer (when disabled)

  def init(state) when is_map(state) do
    {:ok, state}
  end

  def init(state) do
    {:ok, state}
  end

  def handle_connect(%{listening?: false} = state) do
    state = %{state | connected?: true, connection_errors: 0, connection_errors_reported: false}

    # Automatically listen on the channel when connected
    channel_name = channel()
    query("LISTEN #{channel_name}", state)
  end

  def handle_connect(state) do
    {:noreply, %{state | connected?: true}}
  end

  def handle_disconnect(state) do
    {:noreply, %{state | connected?: false, listening?: false}}
  end

  def handle_info({:notification, channel, payload}, state) do
    handle_notification(channel, payload, state)
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove recipient if it died
    recipients = List.delete(state.recipients, pid)
    {:noreply, %{state | recipients: recipients}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  def handle_call({:add_recipient, pid}, from, state) do
    # Monitor the process so we can remove it if it dies
    if is_pid(pid) do
      Process.monitor(pid)
    end

    recipients = [pid | state.recipients] |> Enum.uniq()
    new_state = %{state | recipients: recipients}

    if Config.enable_listen_notify?() do
      # SimpleConnection mode - use Simple.reply
      if from, do: Simple.reply(from, :ok)
      {:noreply, new_state}
    else
      # GenServer mode - return reply tuple
      {:reply, :ok, new_state}
    end
  end

  def handle_call({:remove_recipient, pid}, from, state) do
    recipients = List.delete(state.recipients, pid)
    new_state = %{state | recipients: recipients}

    if Config.enable_listen_notify?() do
      # SimpleConnection mode - use Simple.reply
      if from, do: Simple.reply(from, :ok)
      {:noreply, new_state}
    else
      # GenServer mode - return reply tuple
      {:reply, :ok, new_state}
    end
  end

  def handle_call(:shutdown, from, state) do
    new_state = %{state | shutdown: true}

    if Config.enable_listen_notify?() do
      # SimpleConnection mode - use Simple.reply
      if from, do: Simple.reply(from, :ok)
      {:noreply, new_state}
    else
      # GenServer mode - return reply tuple
      {:reply, :ok, new_state}
    end
  end

  def handle_call(:shutdown?, from, state) do
    if Config.enable_listen_notify?() do
      # SimpleConnection mode - use Simple.reply
      if from, do: Simple.reply(from, state.shutdown)
      {:noreply, state}
    else
      # GenServer mode - return reply tuple
      {:reply, state.shutdown, state}
    end
  end

  def handle_call(:get_state, from, state) do
    # Return connection status for health checks
    status = %{
      connected: state.connected?,
      listening: state.listening?,
      recipients_count: length(state.recipients)
    }

    if Config.enable_listen_notify?() do
      # SimpleConnection mode - use Simple.reply
      if from, do: Simple.reply(from, status)
      {:noreply, state}
    else
      # GenServer mode - return reply tuple
      {:reply, status, state}
    end
  end

  # Handle list of results (Postgrex.SimpleConnection may pass results as a list)
  def handle_result([%Postgrex.Result{} | _], %{listening?: false} = state) do
    # Successfully started listening
    channel_name = channel()
    Logger.info("GoodJob Notifier: Successfully listening on channel #{channel_name}")
    Telemetry.notifier_listen()

    {:noreply, %{state | listening?: true, from: nil, last_keepalive: DateTime.utc_now()}}
  end

  def handle_result([%Postgrex.Result{} | _], state) do
    # Other query succeeded
    {:noreply, %{state | from: nil}}
  end

  def handle_result({:ok, _}, %{from: from, listening?: false} = state) do
    # Successfully started listening
    channel_name = channel()
    Logger.info("GoodJob Notifier: Successfully listening on channel #{channel_name}")
    Telemetry.notifier_listen()

    if from do
      Simple.reply(from, :ok)
    end

    {:noreply, %{state | listening?: true, from: nil, last_keepalive: DateTime.utc_now()}}
  end

  def handle_result({:ok, _}, %{from: from} = state) do
    # Other query succeeded
    if from do
      Simple.reply(from, :ok)
    end

    {:noreply, %{state | from: nil}}
  end

  def handle_result({:error, error} = result, %{from: from} = state) do
    # Query failed
    Logger.error("GoodJob Notifier: Query failed: #{inspect(error)}")
    state = handle_connection_error(state, error)

    if from do
      Simple.reply(from, result)
    end

    {:noreply, %{state | from: nil}}
  end

  # Postgrex.SimpleConnection callback for incoming notifications
  def notify(channel, payload, state) when is_binary(channel) do
    # Update keepalive timestamp
    now = DateTime.utc_now()
    state = %{state | last_keepalive: now}

    if channel == channel() do
      case Jason.decode(payload) do
        {:ok, message} ->
          # Reset connection errors on successful notification
          state = %{state | connection_errors: 0, connection_errors_reported: false}

          # Emit telemetry
          Telemetry.notifier_notified(message)

          # Notify all recipients
          Enum.each(state.recipients, fn recipient ->
            send(recipient, {:good_job_notification, message})
          end)

          state

        {:error, _} ->
          Logger.warning("Failed to parse notification payload: #{payload}")
          state
      end
    else
      state
    end
  end

  # GenServer-only callbacks (for when LISTEN/NOTIFY is disabled)
  # These are only used when we start a regular GenServer (not SimpleConnection)

  def handle_cast({:notify, _message}, state) do
    # LISTEN/NOTIFY is disabled, do nothing
    {:noreply, state}
  end

  def handle_cast({:add_recipient, recipient}, state) do
    # In GenServer mode we receive add_recipient via cast. Monitor the
    # recipient here as well so that handle_info/2 with {:DOWN, ...} can
    # clean up dead recipients, matching the expectations in the tests. We
    # monitor even if the process has already exited so that a DOWN message
    # is delivered immediately, avoiding race conditions.
    if is_pid(recipient) do
      Process.monitor(recipient)
    end

    recipients = [recipient | state.recipients] |> Enum.uniq()
    {:noreply, %{state | recipients: recipients}}
  end

  def handle_cast({:remove_recipient, recipient}, state) do
    recipients = List.delete(state.recipients, recipient)
    {:noreply, %{state | recipients: recipients}}
  end

  # Helpers

  defp query(statement, state) do
    {:query, [statement], state}
  end

  defp handle_notification(_channel, _payload, %{shutdown: true} = state) do
    # Shutting down, ignore notifications
    {:noreply, state}
  end

  defp handle_notification(channel, payload, state) do
    # Update keepalive timestamp
    now = DateTime.utc_now()
    state = %{state | last_keepalive: now}

    if channel == channel() do
      case Jason.decode(payload) do
        {:ok, message} ->
          # Reset connection errors on successful notification
          state = %{state | connection_errors: 0, connection_errors_reported: false}

          # Emit telemetry
          Telemetry.notifier_notified(message)

          # Notify all recipients
          Enum.each(state.recipients, fn recipient ->
            send(recipient, {:good_job_notification, message})
          end)

        {:error, _} ->
          Logger.warning("Failed to parse notification payload: #{payload}")
      end
    end

    {:noreply, state}
  end

  defp handle_connection_error(state, error) do
    # Check if this is a connection-related error
    is_connection_error? =
      case error do
        %Postgrex.Error{} -> true
        %DBConnection.ConnectionError{} -> true
        _ -> false
      end

    if is_connection_error? do
      new_error_count = state.connection_errors + 1

      # Report error if threshold exceeded
      if new_error_count >= @connection_error_threshold and not state.connection_errors_reported do
        Logger.error(
          "GoodJob Notifier connection errors exceeded threshold (#{@connection_error_threshold}). " <>
            "Last error: #{inspect(error)}"
        )

        Telemetry.notifier_connection_error(new_error_count, error)

        %{
          state
          | connection_errors: new_error_count,
            connection_errors_reported: true,
            connected?: false
        }
      else
        %{state | connection_errors: new_error_count, connected?: false}
      end
    else
      # Non-connection error, report immediately
      Logger.error("GoodJob Notifier error: #{inspect(error)}")
      state
    end
  end
end
