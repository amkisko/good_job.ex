defmodule GoodJob.Protocol.TestJobs do
  @moduledoc """
  Test job modules for Protocol integration tests.
  """

  defmodule EmailJob do
    @moduledoc """
    Test job for Protocol integration tests.
    Can be configured to fail for testing retry semantics.
    """
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(args) do
      # Handle both array and direct map formats
      # ActiveJob format wraps arguments in an array: [arg1, arg2, ...]
      # For single argument, it's [arg]
      arg_map =
        case args do
          [arg] when is_map(arg) -> arg
          arg when is_map(arg) -> arg
          _ -> %{}
        end

      # Fail if "fail" key is true (handle both atom and string keys)
      fail = Map.get(arg_map, "fail") || Map.get(arg_map, :fail) || Map.get(arg_map, :fail)

      if fail do
        {:error, "Job failed as requested"}
      else
        :ok
      end
    end
  end

  defmodule PaymentJob do
    @moduledoc """
    Test job for Protocol integration tests.
    Simple job that always succeeds.
    """
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end
end
