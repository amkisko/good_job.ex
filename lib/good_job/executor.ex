defmodule GoodJob.Executor do
  @moduledoc """
  Executor pattern for job execution.

  Provides a structured way to execute jobs with proper state management,
  error handling, and telemetry.
  """

  alias GoodJob.{Job, Telemetry}

  @type t :: %__MODULE__{
          job: Job.t(),
          worker: module() | nil,
          state: atom(),
          result: term(),
          error: Exception.t() | nil,
          start_time: integer(),
          start_mono: integer(),
          duration: integer() | nil,
          safe: boolean()
        }

  defstruct [
    :job,
    :worker,
    :state,
    :result,
    :error,
    :start_time,
    :start_mono,
    :duration,
    safe: true
  ]

  @doc """
  Creates a new executor for a job.
  """
  @spec new(Job.t(), keyword()) :: t()
  def new(job, opts \\ []) do
    safe = Keyword.get(opts, :safe, true)

    %__MODULE__{
      job: job,
      worker: nil,
      state: :unset,
      result: nil,
      error: nil,
      start_time: System.system_time(),
      start_mono: System.monotonic_time(),
      duration: nil,
      safe: safe
    }
  end

  @doc """
  Executes the job through the executor pipeline.
  """
  @spec call(t()) :: t()
  def call(%__MODULE__{} = exec) do
    exec
    |> record_started()
    |> resolve_worker()
    |> perform()
    |> normalize_state()
    |> record_finished()
  end

  defp record_started(%__MODULE__{} = exec) do
    Telemetry.execute_start(exec.job)
    exec
  end

  defp resolve_worker(%__MODULE__{job: job} = exec) do
    case deserialize_worker(job.job_class) do
      {:ok, worker} ->
        %{exec | worker: worker}

      {:error, error} ->
        if exec.safe do
          %{exec | result: {:error, error}, state: :failure, error: error}
        else
          raise error
        end
    end
  end

  defp perform(%__MODULE__{state: :unset, worker: worker, job: job} = exec) do
    args = deserialize_args(job.serialized_params)

    result = worker.perform(args)

    case result do
      :ok ->
        %{exec | state: :success, result: :ok}

      {:ok, _value} = result ->
        %{exec | state: :success, result: result}

      {:cancel, _reason} = result ->
        %{exec | result: result, state: :cancelled, error: format_perform_error(worker, result)}

      :discard ->
        %{exec | result: :discard, state: :discard, error: format_perform_error(worker, :discard)}

      {:discard, _reason} = result ->
        %{exec | result: result, state: :discard, error: format_perform_error(worker, result)}

      {:error, _reason} = result ->
        %{exec | result: result, state: :failure, error: format_perform_error(worker, result)}

      {:snooze, seconds} when is_integer(seconds) and seconds >= 0 ->
        %{exec | result: result, state: :snoozed}

      returned ->
        require Logger
        Logger.warning("Job #{job.id} returned unexpected value: #{inspect(returned)}")
        %{exec | state: :success, result: returned}
    end
  rescue
    error ->
      %{exec | state: :failure, error: error}
  catch
    kind, reason ->
      error = GoodJob.CrashError.exception({kind, reason, __STACKTRACE__})
      %{exec | state: :failure, error: error}
  end

  defp perform(exec), do: exec

  defp normalize_state(%__MODULE__{state: :failure, job: job} = exec) do
    max_attempts = get_max_attempts(job)

    if job.executions_count >= max_attempts do
      %{exec | state: :exhausted}
    else
      exec
    end
  end

  defp normalize_state(exec), do: exec

  defp record_finished(%__MODULE__{} = exec) do
    stop_mono = System.monotonic_time()
    duration = stop_mono - exec.start_mono

    %{exec | duration: duration}
  end

  defp deserialize_worker(job_class) when is_binary(job_class) do
    atom_string = if String.starts_with?(job_class, "Elixir."), do: job_class, else: "Elixir.#{job_class}"

    try do
      atom = String.to_existing_atom(atom_string)

      case Code.ensure_loaded(atom) do
        {:module, module} -> {:ok, module}
        {:error, _} -> {:error, "Job module not found: #{job_class}"}
      end
    rescue
      ArgumentError ->
        # Atom doesn't exist, return error instead of crashing
        {:error, "Job module not found: #{job_class}"}
    end
  end

  defp deserialize_args(%{} = params) do
    Map.get(params, "arguments", params)
  end

  defp deserialize_args(nil), do: %{}

  defp get_max_attempts(job) do
    case deserialize_worker(job.job_class) do
      {:ok, worker} ->
        if function_exported?(worker, :max_attempts, 0) do
          worker.max_attempts()
        else
          25
        end

      _ ->
        25
    end
  end

  defp format_perform_error(_worker, {:error, reason}), do: inspect(reason)
  defp format_perform_error(_worker, {:cancel, reason}), do: inspect(reason)
  defp format_perform_error(_worker, {:discard, reason}), do: inspect(reason)
  defp format_perform_error(_worker, :discard), do: "Job discarded"
end

defmodule GoodJob.CrashError do
  defexception [:message]

  def exception({kind, reason, _stacktrace}) do
    message = "Job crashed: #{kind} - #{inspect(reason)}"
    %__MODULE__{message: message}
  end
end
