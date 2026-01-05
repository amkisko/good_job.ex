defmodule GoodJob.Testing.Assertions do
  @moduledoc """
  Assertion helpers for testing jobs.

  Provides utilities for asserting job state in tests.
  """

  alias GoodJob.{Job, Repo}

  @dialyzer {:nowarn_function, assert_enqueued: 3}
  @dialyzer {:nowarn_function, assert_performed: 1}
  @dialyzer {:nowarn_function, refute_enqueued: 3}

  @doc """
  Asserts that a job was enqueued.

  ## Examples

      assert_enqueued(MyApp.MyJob, %{data: "test"})
      assert_enqueued(MyApp.MyJob, %{data: "test"}, queue: "high_priority")
  """
  def assert_enqueued(job_module, args, opts \\ []) do
    base_query = build_base_query(job_module, opts)
    jobs = Repo.repo().all(base_query)

    # Normalize args for comparison
    normalized_args = normalize_args_for_comparison(args)

    matching_job =
      Enum.find(jobs, fn job ->
        case GoodJob.Protocol.Serialization.from_active_job(job.serialized_params) do
          {:ok, _job_class, job_args, _executions, _metadata} ->
            # Compare arguments - handle both array and direct map cases
            compare_arguments(job_args, normalized_args)

          {:error, _} ->
            # Fallback: try to get arguments directly
            case Map.get(job.serialized_params, "arguments") do
              nil -> false
              job_args -> compare_arguments(job_args, normalized_args)
            end
        end
      end)

    case matching_job do
      nil ->
        raise ExUnit.AssertionError.exception(
                message: """
                Expected job to be enqueued:
                Module: #{inspect(job_module)}
                Args: #{inspect(args)}
                Options: #{inspect(opts)}
                """
              )

      job ->
        job
    end
  end

  @doc """
  Asserts that a job was performed.

  ## Examples

      job = assert_enqueued(MyApp.MyJob, %{data: "test"})
      assert_performed(job)
  """
  def assert_performed(job) do
    job = Repo.repo().get!(Job, job.id)

    if is_nil(job.performed_at) do
      state = Job.calculate_state(job)

      raise ExUnit.AssertionError.exception(
              message: """
              Expected job to be performed:
              Job ID: #{job.id}
              State: #{state}
              """
            )
    end

    job
  end

  @doc """
  Asserts that no jobs were enqueued.

  ## Examples

      refute_enqueued(MyApp.MyJob)
  """
  def refute_enqueued(job_module, args \\ %{}, opts \\ []) do
    query = build_query(job_module, args, opts)

    case Repo.repo().one(query) do
      nil ->
        :ok

      _job ->
        raise ExUnit.AssertionError.exception(
                message: """
                Expected no job to be enqueued:
                Module: #{inspect(job_module)}
                Args: #{inspect(args)}
                Options: #{inspect(opts)}
                """
              )
    end
  end

  # Private functions

  defp normalize_args_for_comparison(args) when is_map(args) do
    # Normalize to string keys for comparison
    Enum.into(args, %{}, fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp normalize_args_for_comparison(args), do: args

  defp compare_arguments(job_args, expected_args) when is_map(expected_args) do
    # If expected is a map, job_args should be [map] or just map
    case job_args do
      [arg_map] when is_map(arg_map) ->
        normalize_map(arg_map) == normalize_map(expected_args)

      arg_map when is_map(arg_map) ->
        normalize_map(arg_map) == normalize_map(expected_args)

      _ ->
        false
    end
  end

  defp compare_arguments(job_args, expected_args) do
    job_args == expected_args
  end

  defp normalize_map(map) do
    Enum.into(map, %{}, fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} -> {k, v}
    end)
  end

  defp build_base_query(job_module, opts) do
    import Ecto.Query

    query =
      from(j in GoodJob.Job,
        where: j.job_class == ^to_string(job_module)
      )

    query =
      if queue = Keyword.get(opts, :queue) do
        where(query, [j], j.queue_name == ^queue)
      else
        query
      end

    query =
      if priority = Keyword.get(opts, :priority) do
        where(query, [j], j.priority == ^priority)
      else
        query
      end

    query
  end

  defp build_query(job_module, _args, opts) do
    # Use the base query builder and filter in Elixir
    build_base_query(job_module, opts)
  end
end
