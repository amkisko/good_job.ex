defmodule GoodJob.Job.Instance do
  @moduledoc """
  Represents a job instance that can be directly executed.

  Created by `MyJob.new(args)` and executed with `.perform`.
  """

  defstruct [:job_module, :args, :options]

  @doc """
  Creates a new job instance.
  """
  def new(job_module, args \\ %{}, options \\ []) do
    %__MODULE__{job_module: job_module, args: args, options: options}
  end

  @doc """
  Executes the job directly without enqueueing.

  Similar to Rails ActiveJob's `job.perform`.

  ## Examples

      job = MyJob.new(%{data: "hello"})
      job.perform()
  """
  def perform(%__MODULE__{job_module: job_module, args: args, options: _options}) do
    if function_exported?(job_module, :perform, 1) do
      normalized_args = normalize_args(args)

      final_args =
        case GoodJob.JobCallbacks.before_perform(job_module, normalized_args, nil) do
          {:ok, modified_args} -> modified_args
          {:error, reason} -> raise "before_perform callback returned error: #{inspect(reason)}"
        end

      result = job_module.perform(final_args)

      GoodJob.JobCallbacks.after_perform(job_module, final_args, nil, result)

      case result do
        :ok -> :ok
        {:ok, value} -> {:ok, value}
        {:error, reason} -> {:error, reason}
        {:discard, reason} -> {:discard, reason}
        other -> other
      end
    else
      raise "Job module #{inspect(job_module)} does not implement perform/1"
    end
  end

  defp normalize_args(args) when is_map(args) do
    args
  end

  defp normalize_args(args), do: args
end
