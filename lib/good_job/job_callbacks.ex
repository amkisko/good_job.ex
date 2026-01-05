defmodule GoodJob.JobCallbacks do
  @moduledoc """
  Job callbacks for lifecycle hooks.

  Supports callbacks:
  - `before_enqueue/2` - Called before job is enqueued
  - `after_enqueue/2` - Called after job is enqueued
  - `before_perform/2` - Called before job is performed
  - `after_perform/2` - Called after job is performed successfully
  - `on_error/3` - Called when job errors
  """

  @doc """
  Executes before_enqueue callback if defined.
  """
  @spec before_enqueue(module(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def before_enqueue(job_module, args, opts) do
    if function_exported?(job_module, :before_enqueue, 2) do
      case job_module.before_enqueue(args, opts) do
        {:ok, modified_args} -> {:ok, modified_args}
        {:error, reason} -> {:error, reason}
        :ok -> {:ok, args}
        other -> {:ok, other || args}
      end
    else
      {:ok, args}
    end
  end

  @doc """
  Executes after_enqueue callback if defined.
  """
  @spec after_enqueue(module(), GoodJob.Job.t(), keyword()) :: :ok
  def after_enqueue(job_module, job, opts) do
    if function_exported?(job_module, :after_enqueue, 2) do
      job_module.after_enqueue(job, opts)
    else
      :ok
    end
  end

  @doc """
  Executes before_perform callback if defined.
  """
  @spec before_perform(module(), map(), GoodJob.Job.t()) :: {:ok, map()} | {:error, term()}
  def before_perform(job_module, args, job) do
    if function_exported?(job_module, :before_perform, 2) do
      case job_module.before_perform(args, job) do
        {:ok, modified_args} -> {:ok, modified_args}
        {:error, reason} -> {:error, reason}
        :ok -> {:ok, args}
        other -> {:ok, other || args}
      end
    else
      {:ok, args}
    end
  end

  @doc """
  Executes after_perform callback if defined.
  """
  @spec after_perform(module(), map(), GoodJob.Job.t(), term()) :: :ok
  def after_perform(job_module, args, job, result) do
    if function_exported?(job_module, :after_perform, 3) do
      job_module.after_perform(args, job, result)
    else
      :ok
    end
  end

  @doc """
  Executes on_error callback if defined.
  """
  @spec on_error(module(), map(), GoodJob.Job.t(), Exception.t()) :: :ok
  def on_error(job_module, args, job, error) do
    if function_exported?(job_module, :on_error, 3) do
      job_module.on_error(args, job, error)
    else
      :ok
    end
  end
end
