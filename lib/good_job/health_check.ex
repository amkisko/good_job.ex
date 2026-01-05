defmodule GoodJob.HealthCheck do
  @moduledoc """
  Health check utilities for GoodJob in production.

  Provides functions to check the health and status of GoodJob components.
  """

  @doc """
  Performs a comprehensive health check of GoodJob.

  Returns `{:ok, status}` if healthy, `{:error, reason}` if unhealthy.

  This check is lenient - it only requires:
  - Database connectivity (required)
  - Supervisor running (required if GoodJob is configured to start)

  Schedulers and Notifier are optional - they may not be running if:
  - Execution mode is :external (schedulers run separately)
  - No queues are configured
  - LISTEN/NOTIFY is disabled
  """
  @spec check() :: {:ok, map()} | {:error, String.t()}
  def check do
    # Required checks
    required_checks = [
      check_database()
    ]

    # Optional checks (warnings, not failures)
    optional_checks = [
      check_supervisor(),
      check_schedulers(),
      check_notifier()
    ]

    # Filter required errors
    required_errors = Enum.filter(required_checks, fn {status, _} -> status == :error end)

    if Enum.empty?(required_errors) do
      # Database is healthy, combine all checks for status
      all_checks = required_checks ++ optional_checks
      status = Enum.into(all_checks, %{}, fn {_, {key, value}} -> {key, value} end)
      {:ok, status}
    else
      reasons = Enum.map(required_errors, fn {_, {_, reason}} -> reason end)
      {:error, Enum.join(reasons, "; ")}
    end
  end

  @doc """
  Checks if the GoodJob supervisor is running.

  Returns `:not_configured` if GoodJob is not configured to start automatically.
  Returns `:not_running` if configured to start but not running (non-fatal).
  """
  @spec check_supervisor() :: {:ok, {:supervisor, :running | :not_configured | :not_running}}
  def check_supervisor do
    # If GoodJob is not configured to start, supervisor not running is OK
    if GoodJob.Config.start_in_application?() do
      case Process.whereis(GoodJob.Supervisor) do
        nil ->
          # Supervisor should be running but isn't - this is a warning, not a failure
          {:ok, {:supervisor, :not_running}}

        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            {:ok, {:supervisor, :running}}
          else
            # Supervisor process is dead - warning, not failure
            {:ok, {:supervisor, :not_running}}
          end
      end
    else
      {:ok, {:supervisor, :not_configured}}
    end
  end

  @doc """
  Checks if schedulers are running.

  Returns `:not_configured` if no schedulers are configured (e.g., execution_mode is :external).
  """
  @spec check_schedulers() :: {:ok, {:schedulers, map() | :not_configured}}
  def check_schedulers do
    # If execution mode is external, schedulers run separately - not an error
    if GoodJob.Config.execution_mode() == :external do
      {:ok, {:schedulers, :not_configured}}
    else
      case Process.whereis(GoodJob.Scheduler.Supervisor) do
        nil ->
          {:ok, {:schedulers, :not_configured}}

        _pid ->
          schedulers = list_schedulers()

          if Enum.empty?(schedulers) do
            # No schedulers running - this is OK if no queues are configured
            {:ok, {:schedulers, :not_configured}}
          else
            status = %{
              count: length(schedulers),
              pids: Enum.map(schedulers, &elem(&1, 1))
            }

            {:ok, {:schedulers, status}}
          end
      end
    end
  end

  @doc """
  Checks if the notifier is running and connected.

  Returns `:not_configured` if LISTEN/NOTIFY is disabled.
  Returns `:not_running` if LISTEN/NOTIFY is enabled but notifier isn't running (non-fatal).
  """
  @spec check_notifier() :: {:ok, {:notifier, map() | :not_configured | :not_running}}
  def check_notifier do
    # If LISTEN/NOTIFY is disabled, notifier not running is OK
    if GoodJob.Config.enable_listen_notify?() do
      case Process.whereis(GoodJob.Notifier) do
        nil ->
          # Notifier should be running but isn't - warning, not failure
          {:ok, {:notifier, :not_running}}

        pid ->
          if Process.alive?(pid) do
            # Try to get notifier state (non-blocking)
            # Use Postgrex.SimpleConnection.call for SimpleConnection, fallback to GenServer.call
            state =
              try do
                if GoodJob.Config.enable_listen_notify?() do
                  Postgrex.SimpleConnection.call(pid, :get_state, 1_000)
                else
                  GenServer.call(pid, :get_state, 1_000)
                end
              rescue
                _ -> %{connected: :unknown}
              catch
                :exit, _ -> %{connected: :unknown}
              end

            {:ok, {:notifier, state}}
          else
            # Notifier process is dead - warning, not failure
            {:ok, {:notifier, :not_running}}
          end
      end
    else
      {:ok, {:notifier, :not_configured}}
    end
  end

  @doc """
  Checks database connectivity.
  """
  @spec check_database() :: {:ok, {:database, :connected}} | {:error, {:database, String.t()}}
  def check_database do
    repo = GoodJob.Config.repo()

    try do
      # Simple query to check connectivity
      repo.query!("SELECT 1", [], timeout: 5_000)
      {:ok, {:database, :connected}}
    rescue
      error ->
        {:error, {:database, "Database connection failed: #{Exception.message(error)}"}}
    catch
      :exit, reason ->
        {:error, {:database, "Database connection timeout: #{inspect(reason)}"}}
    end
  end

  @doc """
  Returns a simple health status string for HTTP health checks.
  """
  @spec status() :: String.t()
  def status do
    case check() do
      {:ok, _} -> "healthy"
      {:error, _} -> "unhealthy"
    end
  end

  defp list_schedulers do
    Registry.select(GoodJob.Registry, [
      {{:_, :"$1", :"$2"}, [{:==, :"$1", {:scheduler, :_}}], [:"$2"]}
    ])
  rescue
    _ -> []
  end
end
