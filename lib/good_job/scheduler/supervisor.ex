defmodule GoodJob.Scheduler.Supervisor do
  @moduledoc """
  Supervisor for job schedulers.

  Manages multiple scheduler processes, one per queue configuration.
  """

  use Supervisor

  @doc """
  Starts the scheduler supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    queue_string = GoodJob.Config.queues() || "*"
    max_processes = GoodJob.Config.max_processes()
    cleanup_interval_seconds = GoodJob.Config.cleanup_interval_seconds()
    cleanup_interval_jobs = GoodJob.Config.cleanup_interval_jobs()

    children = parse_queues(queue_string, max_processes, cleanup_interval_seconds, cleanup_interval_jobs)

    spawn_link(fn ->
      Process.sleep(200)
      register_schedulers_with_poller()
    end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp register_schedulers_with_poller do
    case Process.whereis(GoodJob.Poller) do
      nil ->
        :ok

      _poller_pid ->
        schedulers = Supervisor.which_children(__MODULE__)

        Enum.each(schedulers, fn {_id, pid, _type, _modules} ->
          if pid != :undefined and pid != nil and Process.alive?(pid) do
            GoodJob.Poller.add_recipient(pid)
          end
        end)
    end
  end

  defp parse_queues("*", max_processes, cleanup_interval_seconds, cleanup_interval_jobs) do
    [
      Supervisor.child_spec(
        {GoodJob.Scheduler,
         [
           queue_string: "*",
           max_processes: max_processes,
           cleanup_interval_seconds: cleanup_interval_seconds,
           cleanup_interval_jobs: cleanup_interval_jobs
         ]},
        id: unique_scheduler_id("*")
      )
    ]
  end

  defp parse_queues(queue_string, default_processes, cleanup_interval_seconds, cleanup_interval_jobs) do
    cond do
      String.contains?(queue_string, ";") ->
        pools =
          queue_string
          |> String.split(";")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        Enum.flat_map(pools, fn pool_spec ->
          parse_pool(pool_spec, default_processes, cleanup_interval_seconds, cleanup_interval_jobs)
        end)

      String.starts_with?(queue_string, "-") or String.starts_with?(queue_string, "+") ->
        [parse_single_pool(queue_string, default_processes, cleanup_interval_seconds, cleanup_interval_jobs)]

      true ->
        parse_queues_legacy(queue_string, default_processes, cleanup_interval_seconds, cleanup_interval_jobs)
    end
  end

  defp parse_single_pool(pool_spec, default_processes, cleanup_interval_seconds, cleanup_interval_jobs) do
    case String.split(pool_spec, ":") do
      [queue_string] ->
        Supervisor.child_spec(
          {GoodJob.Scheduler,
           [
             queue_string: queue_string,
             max_processes: default_processes,
             cleanup_interval_seconds: cleanup_interval_seconds,
             cleanup_interval_jobs: cleanup_interval_jobs,
             name: scheduler_name(queue_string)
           ]},
          id: unique_scheduler_id(queue_string)
        )

      parts when length(parts) >= 2 ->
        concurrency_count_str = List.last(parts)
        queue_string = Enum.take(parts, length(parts) - 1) |> Enum.join(":")

        concurrency =
          case Integer.parse(String.trim(concurrency_count_str)) do
            {concurrency, _} -> concurrency
            :error -> default_processes
          end

        Supervisor.child_spec(
          {GoodJob.Scheduler,
           [
             queue_string: queue_string,
             max_processes: concurrency,
             cleanup_interval_seconds: cleanup_interval_seconds,
             cleanup_interval_jobs: cleanup_interval_jobs,
             name: scheduler_name(queue_string)
           ]},
          id: unique_scheduler_id(queue_string)
        )
    end
  end

  defp parse_pool(pool_spec, default_processes, cleanup_interval_seconds, cleanup_interval_jobs) do
    case String.split(pool_spec, ":") do
      [queue_string] ->
        [
          Supervisor.child_spec(
            {GoodJob.Scheduler,
             [
               queue_string: queue_string,
               max_processes: default_processes,
               cleanup_interval_seconds: cleanup_interval_seconds,
               cleanup_interval_jobs: cleanup_interval_jobs,
               name: scheduler_name(queue_string)
             ]},
            id: unique_scheduler_id(queue_string)
          )
        ]

      parts when length(parts) >= 2 ->
        concurrency_count_str = List.last(parts)
        queue_string = Enum.take(parts, length(parts) - 1) |> Enum.join(":")

        concurrency =
          case Integer.parse(String.trim(concurrency_count_str)) do
            {concurrency, _} -> concurrency
            :error -> default_processes
          end

        [
          Supervisor.child_spec(
            {GoodJob.Scheduler,
             [
               queue_string: queue_string,
               max_processes: concurrency,
               cleanup_interval_seconds: cleanup_interval_seconds,
               cleanup_interval_jobs: cleanup_interval_jobs,
               name: scheduler_name(queue_string)
             ]},
            id: unique_scheduler_id(queue_string)
          )
        ]
    end
  end

  defp parse_queues_legacy(queue_string, default_processes, cleanup_interval_seconds, cleanup_interval_jobs) do
    queue_string
    |> String.split(",")
    |> Enum.map(fn queue_spec ->
      queue_spec = String.trim(queue_spec)

      case String.split(queue_spec, ":") do
        [queue_name] ->
          Supervisor.child_spec(
            {GoodJob.Scheduler,
             [
               queue_string: queue_name,
               max_processes: default_processes,
               cleanup_interval_seconds: cleanup_interval_seconds,
               cleanup_interval_jobs: cleanup_interval_jobs,
               name: scheduler_name(queue_name)
             ]},
            id: unique_scheduler_id(queue_name)
          )

        parts when length(parts) >= 2 ->
          concurrency_count_str = List.last(parts)
          queue_name = Enum.take(parts, length(parts) - 1) |> Enum.join(":")

          concurrency =
            case Integer.parse(String.trim(concurrency_count_str)) do
              {concurrency, _} -> concurrency
              :error -> default_processes
            end

          Supervisor.child_spec(
            {GoodJob.Scheduler,
             [
               queue_string: queue_name,
               max_processes: concurrency,
               cleanup_interval_seconds: cleanup_interval_seconds,
               cleanup_interval_jobs: cleanup_interval_jobs,
               name: scheduler_name(queue_name)
             ]},
            id: unique_scheduler_id(queue_name)
          )
      end
    end)
  end

  defp scheduler_name(queue_string) do
    {:via, Registry, {GoodJob.Registry, {:scheduler, queue_string}}}
  end

  defp unique_scheduler_id(queue_string) do
    {:scheduler, queue_string, System.unique_integer([:positive])}
  end
end
