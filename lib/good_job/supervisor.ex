defmodule GoodJob.Supervisor do
  @moduledoc """
  Main supervisor for GoodJob.

  Manages all GoodJob processes including:
  - Notifier (LISTEN/NOTIFY)
  - Poller (scheduled jobs)
  - CronManager (cron jobs)
  - Scheduler supervisors (job execution)
  """

  use Supervisor

  @doc """
  Starts the GoodJob supervisor.

  If the supervisor is already started, returns `{:error, {:already_started, pid}}`
  where `pid` is the existing supervisor process.
  """
  def start_link(opts \\ []) do
    # Check if already started
    case Process.whereis(__MODULE__) do
      nil ->
        Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

      pid ->
        {:error, {:already_started, pid}}
    end
  end

  @doc """
  Shuts down all GoodJob processes gracefully.

  ## Options

    * `:timeout` - Timeout in seconds. `-1` means wait forever, `0` means immediate shutdown.
  """
  def shutdown(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, -1)

    # Shutdown all child processes
    shutdown_processes(timeout)
  end

  @doc """
  Checks if GoodJob is shut down.

  Returns `true` if all processes are shut down, `false` otherwise.
  """
  def shutdown? do
    # Check if all processes are shut down
    notifier_shutdown? = check_shutdown(GoodJob.Notifier)
    poller_shutdown? = check_shutdown(GoodJob.Poller)
    cron_shutdown? = check_shutdown(GoodJob.CronManager)

    # Check schedulers
    schedulers_shutdown? =
      case Process.whereis(SchedulerSupervisor) do
        nil -> true
        pid -> check_schedulers_shutdown(pid)
      end

    notifier_shutdown? && poller_shutdown? && cron_shutdown? && schedulers_shutdown?
  end

  defp shutdown_processes(timeout) do
    # Shutdown in order: schedulers, cron manager, poller, notifier
    shutdown_schedulers(timeout)
    shutdown_cron_manager(timeout)
    shutdown_poller(timeout)
    shutdown_notifier(timeout)
    :ok
  end

  defp shutdown_schedulers(timeout) do
    case Process.whereis(SchedulerSupervisor) do
      nil ->
        :ok

      _pid ->
        # Get all scheduler PIDs
        schedulers = get_scheduler_pids()

        # Shutdown each scheduler
        Enum.each(schedulers, fn scheduler_pid ->
          if Process.alive?(scheduler_pid) do
            GenServer.call(scheduler_pid, {:shutdown, timeout}, :infinity)
          end
        end)
    end
  end

  defp shutdown_cron_manager(timeout) do
    case Process.whereis(GoodJob.CronManager) do
      nil -> :ok
      pid -> GenServer.call(pid, :shutdown, timeout_to_ms(timeout))
    end
  end

  defp shutdown_poller(timeout) do
    case Process.whereis(GoodJob.Poller) do
      nil -> :ok
      pid -> GenServer.call(pid, :shutdown, timeout_to_ms(timeout))
    end
  end

  defp shutdown_notifier(timeout) do
    case Process.whereis(GoodJob.Notifier) do
      nil -> :ok
      pid -> GenServer.call(pid, :shutdown, timeout_to_ms(timeout))
    end
  end

  defp check_shutdown(module) do
    case Process.whereis(module) do
      nil -> true
      pid -> GenServer.call(pid, :shutdown?, timeout_to_ms(5))
    end
  rescue
    _ -> false
  end

  defp check_schedulers_shutdown(_supervisor_pid) do
    schedulers = get_scheduler_pids()

    Enum.all?(schedulers, fn scheduler_pid ->
      if Process.alive?(scheduler_pid) do
        try do
          GenServer.call(scheduler_pid, :shutdown?, timeout_to_ms(5))
        rescue
          _ -> false
        end
      else
        true
      end
    end)
  end

  defp get_scheduler_pids do
    # Get all scheduler PIDs from the registry
    Registry.select(GoodJob.Registry, [
      {{:_, :"$1", :"$2"}, [{:==, :"$1", {:scheduler, :_}}], [:"$2"]}
    ])
  end

  defp timeout_to_ms(-1), do: :infinity
  defp timeout_to_ms(0), do: 0
  defp timeout_to_ms(timeout) when timeout > 0, do: timeout * 1000

  @impl true
  def init(_opts) do
    config = GoodJob.Config.config()

    children =
      [
        # Registry for process lookup
        {Registry, keys: :unique, name: GoodJob.Registry},
        # Process tracker for advisory locks
        {GoodJob.ProcessTracker, []},
        # Notifier for LISTEN/NOTIFY
        {GoodJob.Notifier, []},
        # Poller for scheduled jobs
        {GoodJob.Poller,
         [
           poll_interval: GoodJob.Config.poll_interval(),
           recipients: []
         ]},
        # Cron manager (if enabled)
        if GoodJob.Config.enable_cron?() do
          cron_entries = GoodJob.Config.cron_entries()

          {GoodJob.CronManager,
           cron_entries: cron_entries, graceful_restart_period: GoodJob.Config.cron_graceful_restart_period()}
        end,
        # Scheduler supervisor
        {GoodJob.Scheduler.Supervisor, []}
        # Plugins (if configured)
        | Enum.map(GoodJob.Config.plugins(), &plugin_child_spec(&1, config))
      ]
      |> Enum.filter(&(&1 != nil))

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp plugin_child_spec({module, opts}, conf) when is_atom(module) do
    name = {:via, Registry, {GoodJob.Registry, {:plugin, module}}}
    opts = Keyword.merge(opts, conf: conf, name: name)

    # Validate plugin options
    case module.validate(opts) do
      :ok ->
        Supervisor.child_spec({module, opts}, id: {:plugin, module})

      {:error, reason} ->
        raise ArgumentError, "Plugin #{inspect(module)} validation failed: #{reason}"
    end
  end

  defp plugin_child_spec(module, conf) when is_atom(module) do
    plugin_child_spec({module, []}, conf)
  end
end
