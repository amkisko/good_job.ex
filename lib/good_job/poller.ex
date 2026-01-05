defmodule GoodJob.Poller do
  @moduledoc """
  Poller that regularly wakes up schedulers to check for new work.

  The poller runs independently of LISTEN/NOTIFY and ensures jobs are
  checked even if notifications fail.
  """

  use GenServer
  require Logger

  alias GoodJob.{Config, JobPerformer}

  @doc """
  Starts the poller.
  """
  def start_link(opts \\ []) do
    poll_interval = Keyword.get(opts, :poll_interval, Config.poll_interval())
    recipients = Keyword.get(opts, :recipients, [])

    GenServer.start_link(__MODULE__, {poll_interval, recipients}, name: __MODULE__)
  end

  @doc """
  Adds a recipient to receive poll notifications.
  """
  def add_recipient(recipient) do
    GenServer.cast(__MODULE__, {:add_recipient, recipient})
  end

  @doc """
  Removes a recipient from poll notifications.
  """
  def remove_recipient(recipient) do
    GenServer.cast(__MODULE__, {:remove_recipient, recipient})
  end

  @impl true
  def init({poll_interval, recipients}) do
    # Parse configured queues for filtering notifications
    queue_string = Config.queues() || "*"
    parsed_queues = JobPerformer.parse_queues(queue_string)

    state = %{
      poll_interval: poll_interval,
      recipients: recipients,
      running: true,
      parsed_queues: parsed_queues
    }

    # Register as recipient of Notifier for immediate notifications
    if GoodJob.Config.enable_listen_notify?() do
      case Process.whereis(GoodJob.Notifier) do
        nil ->
          # Notifier not started yet, will register later
          Process.send_after(self(), :register_notifier, 100)

        _notifier_pid ->
          register_with_notifier()
      end
    end

    # Start polling if interval is valid.
    #
    # Important: schedule the first poll after the configured interval rather than
    # immediately. The tests expect that polling only happens when:
    #   * a :poll message is explicitly sent, or
    #   * a {:good_job_notification, ...} message matches the queue filters.
    #
    # If we scheduled an immediate poll here, tests that assert "no poll should
    # happen in response to this notification" would see the background poll
    # instead, causing flakiness.
    if poll_interval > 0 do
      schedule_poll(poll_interval * 1000)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:register_notifier, state) do
    case Process.whereis(GoodJob.Notifier) do
      nil ->
        # Still not started, try again
        Process.send_after(self(), :register_notifier, 100)
        {:noreply, state}

      _notifier_pid ->
        register_with_notifier()
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:good_job_notification, message}, state) do
    # Received notification from Notifier - check if we should trigger poll
    should_poll =
      case message do
        %{"queue_name" => queue_name} ->
          # Ruby GoodJob format: { queue_name: "...", scheduled_at: "..." }
          # Only trigger poll if this queue matches our configuration
          queue_matches?(queue_name, state.parsed_queues)

        _ ->
          # Other notification types (e.g., job_completed), ignore
          false
      end

    if should_poll do
      send(self(), :poll)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, %{running: true, recipients: recipients} = state) do
    # Notify all recipients
    Enum.each(recipients, fn recipient ->
      send(recipient, :poll)
    end)

    # Schedule next poll
    schedule_poll(state.poll_interval * 1000)

    {:noreply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    # Not running, don't poll
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_recipient, recipient}, state) do
    recipients = [recipient | state.recipients] |> Enum.uniq()
    {:noreply, %{state | recipients: recipients}}
  end

  @impl true
  def handle_cast({:remove_recipient, recipient}, state) do
    recipients = List.delete(state.recipients, recipient)
    {:noreply, %{state | recipients: recipients}}
  end

  @impl true
  def handle_call(:shutdown, _from, state) do
    {:reply, :ok, %{state | running: false}}
  end

  @impl true
  def handle_call(:shutdown?, _from, state) do
    {:reply, not state.running, state}
  end

  defp schedule_poll(delay_ms) when is_integer(delay_ms) and delay_ms >= 0 do
    Process.send_after(self(), :poll, delay_ms)
  end

  defp register_with_notifier do
    # Register this Poller as a recipient of Notifier
    GoodJob.Notifier.add_recipient(self())
  end

  # Check if a queue name matches our configured queues
  defp queue_matches?(_queue_name, %{} = parsed_queues) when map_size(parsed_queues) == 0 do
    # Empty map means "*" - all queues match
    true
  end

  defp queue_matches?(queue_name, %{exclude: exclude_queues}) do
    # If queue is in exclude list, it doesn't match
    not Enum.member?(exclude_queues, queue_name)
  end

  defp queue_matches?(queue_name, %{include: include_queues}) do
    # If queue is in include list, it matches
    Enum.member?(include_queues, queue_name)
  end

  defp queue_matches?(queue_name, %{include: include_queues, ordered_queues: _}) do
    # Ordered queues also use include list
    Enum.member?(include_queues, queue_name)
  end

  defp queue_matches?(_queue_name, _parsed_queues) do
    # Unknown format, default to matching (safe fallback)
    true
  end
end
