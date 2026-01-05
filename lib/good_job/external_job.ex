defmodule GoodJob.ExternalJob do
  @moduledoc """
  Extension for enqueueing jobs to be processed by external GoodJob workers.

  This extension prevents local execution (inline/async) since the job logic
  is implemented in an external language, not Elixir. It automatically handles:
  - Serialization in ActiveJob format according to Protocol
  - Validation that the job can be processed by external workers

  ## Usage

  In a monorepo setup where both external languages and Elixir code coexist:

      # Define the job in Elixir (metadata only, logic is in external language)
      defmodule MyApp.ProcessPaymentJob do
        use GoodJob.ExternalJob, queue: "payments"
      end

      # Enqueue the job (will be processed by external workers)
      MyApp.ProcessPaymentJob.perform_later(%{user_id: 123, amount: 100.00})

      # perform_now is not supported for ExternalJob (raises LocalExecutionError)
      MyApp.ProcessPaymentJob.perform_now(%{user_id: 123})
      # => raises GoodJob.ExternalJob.LocalExecutionError

  ## Monorepo Setup

  In a monorepo where both external languages and Elixir code share the same database:

      1. Define job metadata in Elixir (this module)
      2. Implement job logic in external language (e.g., Ruby, Zig, etc.)
      3. Configure the mapping in `external_jobs` config (if needed)

      4. Enqueue from Elixir, process in external language

  ## External Jobs Configuration

  The external language side should have the job class defined:

      # In Ruby (app/jobs/process_payment_job.rb)
      class ProcessPaymentJob < ApplicationJob
        def perform(user_id:, amount:)
          # Job logic here
        end
      end

  This allows the external worker to deserialize and execute the job.
  """

  defmodule LocalExecutionError do
    defexception [:message]

    def exception(job_module) do
      message =
        "Cannot execute #{inspect(job_module)} locally. " <>
          "This job is configured to run on external workers only. " <>
          "Use `enqueue/2` to enqueue the job instead."

      %__MODULE__{message: message}
    end
  end

  @doc """
  Defines an ExternalJob module.

  This macro sets up a job that can only be enqueued (not executed locally),
  and ensures it's configured for external processing.

  ## Options

    * `:queue` - Default queue name
    * `:priority` - Default priority (default: 0)

  ## Examples

      defmodule MyApp.ProcessPaymentJob do
        use GoodJob.ExternalJob, queue: "payments"
      end
  """
  defmacro __using__(opts \\ []) do
    queue = Keyword.get(opts, :queue, "default")
    priority = Keyword.get(opts, :priority, 0)

    quote bind_quoted: [queue: queue, priority: priority] do
      @behaviour GoodJob.Behaviour

      @doc """
      Default queue for this job.
      """
      def __good_job_queue__, do: unquote(queue)

      @doc """
      Default priority for this job.
      """
      def __good_job_priority__, do: unquote(priority)

      @doc """
      Default max attempts for this job (not used for external jobs, but required by interface).
      """
      def __good_job_max_attempts__, do: 5

      @doc """
      Default timeout for this job (not used for external jobs, but required by interface).
      """
      def __good_job_timeout__, do: :infinity

      @doc """
      Default tags for this job.
      """
      def __good_job_tags__, do: []

      @doc """
      Enqueues this job with the given arguments.

      The job will be processed by external workers. Local execution is not allowed.

      Prefer using `perform_later/1` for ActiveJob-style API.
      """
      def enqueue(args, opts \\ []) do
        # Validate execution mode
        execution_mode = Keyword.get(opts, :execution_mode, :async)

        if execution_mode in [:inline, :external] do
          raise LocalExecutionError, __MODULE__
        end

        queue_name = Keyword.get(opts, :queue) || __good_job_queue__()

        # Use Protocol helper to enqueue for external language
        default_opts = [
          queue: queue_name,
          priority: Keyword.get(opts, :priority, __good_job_priority__()),
          tags: Keyword.get(opts, :tags, __good_job_tags__())
        ]

        opts = Keyword.merge(default_opts, opts)

        # Look up external class name from external_jobs config, or fall back to auto-conversion
        external_class = GoodJob.ExternalJob.find_external_class(__MODULE__)
        GoodJob.Protocol.enqueue_for_external(external_class, args, opts)
      end

      @doc """
      Enqueues the job for later execution (ActiveJob-style API).

      This is the preferred method for enqueueing ExternalJob instances.

      You can override this function with pattern matching to validate arguments:

          defmodule MyApp.ProcessPaymentJob do
            use GoodJob.ExternalJob, queue: "payments"

            # Override with pattern matching for argument validation
            def perform_later(%{user_id: user_id, amount: amount}) when is_integer(user_id) and is_float(amount) do
              super(%{user_id: user_id, amount: amount})
            end
          end

      This ensures arguments are validated before the job is enqueued to the database.
      """
      def perform_later(args \\ %{}) do
        enqueue(args, [])
      end

      @doc """
      Attempts to execute the job immediately (not supported for ExternalJob).

      Raises `LocalExecutionError` since job logic is in external language, not Elixir.
      """
      def perform_now(_args \\ %{}) do
        raise LocalExecutionError, __MODULE__
      end

      @doc """
      This function is not implemented for ExternalJob.

      Raises `LocalExecutionError` since job logic is in external language.
      """
      def perform(_args) do
        raise LocalExecutionError, __MODULE__
      end

      defoverridable perform: 1, perform_later: 1
    end
  end

  @doc """
  Converts Elixir module name to external class name format.

  Delegates to `GoodJob.Protocol.Serialization.module_to_external_class/1`.

  ## Examples

      GoodJob.ExternalJob.module_to_external_class(MyApp.ProcessPaymentJob)
      # => "MyApp::ProcessPaymentJob"

      GoodJob.ExternalJob.module_to_external_class("MyApp.ProcessPaymentJob")
      # => "MyApp::ProcessPaymentJob"
  """
  @spec module_to_external_class(module() | String.t()) :: String.t()
  defdelegate module_to_external_class(module), to: GoodJob.Protocol.Serialization

  @doc """
  Finds the external class name for an Elixir module by looking it up in external_jobs config.

  If the module is found in external_jobs config values, returns the corresponding external class name (the key).
  Otherwise, falls back to auto-converting the module name to external format.
  """
  @spec find_external_class(module()) :: String.t()
  def find_external_class(elixir_module) do
    external_jobs = GoodJob.Config.external_jobs()

    # Search for the Elixir module in the config values
    # The config is structured as: %{"ExternalJobClass" => Elixir.Module.Name}
    # We need to find the Elixir module in the values and return the corresponding key
    case Enum.find(external_jobs, fn {_external_class, mapped_module} -> mapped_module == elixir_module end) do
      {external_class, _module} ->
        # Found in config, use the external class name (the key)
        external_class

      nil ->
        # Not found in config, auto-convert module name to external format
        # This converts "MonorepoExample.Jobs.ExampleExternalJob" to "MonorepoExample::Jobs::ExampleExternalJob"
        # This fallback may not match the actual external class name if the naming differs
        # (e.g., if Elixir module is "ExampleExternalJob" but external class is "ExampleJob")
        # In such cases, ensure the mapping is configured in external_jobs config
        module_to_external_class(elixir_module)
    end
  end
end
