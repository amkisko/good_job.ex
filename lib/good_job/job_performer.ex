defmodule GoodJob.JobPerformer do
  @moduledoc """
  Performs jobs by querying the database and executing them.

  This module is responsible for:
  - Selecting the next eligible job
  - Acquiring advisory locks
  - Executing jobs
  - Handling retries
  """

  alias GoodJob.{AdvisoryLock, Job, Repo}
  import Ecto.Query

  @doc """
  Performs the next eligible job.

  Returns `{:ok, result}` if a job was executed, `{:ok, nil}` if no job was found.
  """
  def perform_next(queue_string, lock_id, opts \\ []) do
    queue_select_limit =
      Keyword.get(opts, :queue_select_limit) ||
        GoodJob.Config.queue_select_limit() ||
        1000

    parsed_queues = parse_queues(queue_string)
    repo = Repo.repo()

    case repo.transaction(fn ->
           case select_and_lock_job(repo, parsed_queues, lock_id, queue_select_limit) do
             nil ->
               nil

             job ->
               now = DateTime.utc_now()

               job
               |> Job.changeset(%{
                 locked_by_id: lock_id,
                 locked_at: now,
                 performed_at: now,
                 executions_count: (job.executions_count || 0) + 1
               })
               |> repo.update!()
               |> then(&repo.get!(Job, &1.id))
           end
         end) do
      {:ok, nil} ->
        GoodJob.Telemetry.scheduler_job_not_found(queue_string)
        {:ok, nil}

      {:ok, job} ->
        GoodJob.Telemetry.scheduler_job_fetched(job, queue_string)
        GoodJob.Telemetry.job_locked(job, lock_id)
        GoodJob.PubSub.broadcast(:job_updated, job.id)
        {:ok, job}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc false
  def select_and_lock_job(queue_string, lock_id) when is_binary(queue_string) do
    repo = Repo.repo()
    parsed_queues = parse_queues(queue_string)
    limit = GoodJob.Config.queue_select_limit() || 1000
    select_and_lock_job_internal(repo, parsed_queues, lock_id, limit)
  end

  defp select_and_lock_job(repo, parsed_queues, lock_id, limit) do
    select_and_lock_job_internal(repo, parsed_queues, lock_id, limit)
  end

  defp select_and_lock_job_internal(repo, parsed_queues, _lock_id, limit) do
    now = DateTime.utc_now()
    stale_lock_cutoff = DateTime.add(now, -60, :second)

    repo.update_all(
      from(j in Job,
        where: is_nil(j.finished_at),
        where: not is_nil(j.locked_by_id),
        where: j.locked_at < ^stale_lock_cutoff
      ),
      set: [locked_by_id: nil, locked_at: nil, performed_at: nil]
    )

    query =
      Job
      |> Job.unfinished()
      |> Job.unlocked()
      |> filter_queues(parsed_queues)
      |> where([j], is_nil(j.scheduled_at) or j.scheduled_at <= ^now)
      |> Job.order_for_candidate_lookup(parsed_queues)
      |> limit(^limit)

    candidates = repo.all(query)

    Enum.find_value(candidates, fn job ->
      if is_nil(job.finished_at) do
        lock_key = AdvisoryLock.job_id_to_lock_key(job.id)

        case AdvisoryLock.lock(lock_key) do
          true -> job
          false -> nil
        end
      else
        nil
      end
    end)
  end

  defp filter_queues(query, %{include: queues}) when is_list(queues) do
    {invalid_patterns, exact_queues} =
      Enum.split_with(queues, fn queue ->
        String.contains?(queue, "*") and queue != "*"
      end)

    if not Enum.empty?(invalid_patterns) do
      raise ArgumentError,
            "Only '*' is supported as a wildcard. Patterns like '#{List.first(invalid_patterns)}' are not supported."
    end

    if "*" in queues do
      query
    else
      if Enum.empty?(exact_queues) do
        where(query, [j], false)
      else
        where(query, [j], j.queue_name in ^exact_queues)
      end
    end
  end

  defp filter_queues(query, %{exclude: queues}) when is_list(queues) do
    where(query, [j], j.queue_name not in ^queues)
  end

  defp filter_queues(query, _) do
    query
  end

  @doc """
  Parses a queue string into a map with :include, :exclude, or :ordered_queues keys.

  Strips concurrency values (e.g., ":5" suffix) from queue names before parsing.
  This function only parses queue names, not concurrency counts.

  Examples:
    - "*" -> %{}
    - "queue1,queue2" -> %{include: ["queue1", "queue2"]}
    - "queue1:5,queue2:10" -> %{include: ["queue1", "queue2"]} (concurrency stripped)
    - "-queue1" -> %{exclude: ["queue1"]}
    - "+queue1,queue2" -> %{include: ["queue1", "queue2"], ordered_queues: true}
    - "+queue1,queue2:5" -> %{include: ["queue1", "queue2"], ordered_queues: true}

  Only supports "*" as a wildcard (standalone, not in patterns like "queue*").
  """
  def parse_queues("*"), do: %{}

  # Support Ruby-style exclude syntax like "*,!excluded" by translating it into
  # the internal "-excluded" format that the rest of the parser understands.
  def parse_queues(queue_string) when is_binary(queue_string) do
    queue_string = String.trim(queue_string)

    # When the queue string includes "!" (Ruby-style excludes), normalise it
    # first and then delegate to the main parser.
    if String.contains?(queue_string, "!") do
      parse_queues_with_excludes(queue_string)
    else
      do_parse_queues(queue_string)
    end
  end

  defp parse_queues_with_excludes(queue_string) do
    parts =
      queue_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    {stars, others} = Enum.split_with(parts, &(&1 == "*"))

    exclude_parts =
      others
      |> Enum.filter(&String.starts_with?(&1, "!"))
      |> Enum.map(&String.trim_leading(&1, "!"))
      |> Enum.reject(&(&1 == ""))

    # When we see a wildcard plus one or more explicit excludes using "!"
    # (e.g. "*,!excluded"), treat this as "all queues except these" by
    # converting to the "-excluded" syntax.
    if stars != [] and exclude_parts != [] do
      converted = Enum.map_join(exclude_parts, ",", &("-" <> &1))

      do_parse_queues(converted)
    else
      do_parse_queues(queue_string)
    end
  end

  defp do_parse_queues(queue_string) do
    if queue_string == "" do
      %{}
    else
      {ordered_queues, exclude_queues, trimmed_string} =
        cond do
          String.starts_with?(queue_string, "+") ->
            {true, false, String.slice(queue_string, 1..-1//1)}

          String.starts_with?(queue_string, "-") ->
            {false, true, String.slice(queue_string, 1..-1//1)}

          true ->
            {false, false, queue_string}
        end

      queue_parts =
        trimmed_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      {exclude_list, include_list} =
        if exclude_queues do
          {queue_parts, []}
        else
          Enum.split_with(queue_parts, fn queue_part ->
            String.starts_with?(queue_part, "-")
          end)
        end

      exclude_queues_list =
        exclude_list
        |> Enum.map(fn queue_part ->
          if String.starts_with?(queue_part, "-") do
            queue_part
            |> String.slice(1..-1//1)
            |> strip_concurrency()
          else
            strip_concurrency(queue_part)
          end
        end)
        |> Enum.reject(&(&1 == ""))

      include_queues_list =
        include_list
        |> Enum.map(&strip_concurrency/1)
        |> Enum.reject(&(&1 == ""))

      has_exclude = not Enum.empty?(exclude_queues_list)
      has_include = not Enum.empty?(include_queues_list)

      if has_exclude and has_include do
        %{exclude: exclude_queues_list}
      else
        queues = if has_exclude, do: exclude_queues_list, else: include_queues_list

        if Enum.any?(queues, &(&1 == "*")) do
          %{}
        else
          invalid_patterns =
            Enum.filter(queues, fn queue ->
              String.contains?(queue, "*") and queue != "*"
            end)

          if not Enum.empty?(invalid_patterns) do
            raise ArgumentError,
                  "Only '*' is supported as a wildcard. Patterns like '#{List.first(invalid_patterns)}' are not supported."
          end

          cond do
            has_exclude ->
              %{exclude: queues}

            ordered_queues ->
              %{include: queues, ordered_queues: true}

            true ->
              %{include: queues}
          end
        end
      end
    end
  end

  defp strip_concurrency(queue_string) do
    case String.split(queue_string, ":") do
      [queue_name] ->
        queue_name

      parts when length(parts) >= 2 ->
        last_part = List.last(parts)

        if String.match?(last_part, ~r/^\d+$/) do
          Enum.take(parts, length(parts) - 1) |> Enum.join(":")
        else
          queue_string
        end
    end
  end
end
