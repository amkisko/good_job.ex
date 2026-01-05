defmodule GoodJob.JobExecutor.ErrorHandler do
  @moduledoc """
  Handles error classification and discard_on checking.
  """

  @doc """
  Checks if an error should trigger discard based on job's discard_on configuration.
  """
  def check_discard_on(nil, _error), do: false

  def check_discard_on(job_module, error) do
    if function_exported?(job_module, :__good_job_discard_on__, 0) do
      exceptions = job_module.__good_job_discard_on__()
      check_exception_match(error, exceptions)
    else
      false
    end
  end

  defp check_exception_match(_error, []), do: false

  defp check_exception_match(error, [exception | rest]) do
    if exception_matches?(error, exception) do
      true
    else
      check_exception_match(error, rest)
    end
  end

  defp exception_matches?(error, exception) when is_atom(exception) do
    error_module = error.__struct__
    error_module == exception
  end

  defp exception_matches?(_error, _exception), do: false
end
