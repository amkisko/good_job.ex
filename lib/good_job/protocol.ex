defmodule GoodJob.Protocol do
  @moduledoc """
  GoodJob Ruby protocol helpers (internal/advanced use).

  This module provides low-level helpers for enqueueing jobs that follow the
  GoodJob Ruby protocol and ActiveJob conventions. All conversions and transformations
  follow good_job and active_job conventions.

  **Note:** For most use cases, prefer using descriptor modules with `perform_later/1`:

      # Preferred: Use descriptor module with perform_later
      MyApp.ProcessPaymentJob.perform_later(%{user_id: 123})

      # Advanced: Direct protocol enqueueing (when no descriptor module exists)
      GoodJob.Protocol.enqueue_for_external("MyApp::ProcessPaymentJob", %{user_id: 123})

  ## When to use

  - Use `perform_later/1` on descriptor modules (recommended)
  - Use `enqueue_for_external/3` or `enqueue_for_elixir/3` only when you need to enqueue
    jobs without a descriptor module (e.g., ad-hoc jobs from external languages)
  """

  @doc """
  Enqueues a job to be processed by external GoodJob workers.

  The job will be serialized in ActiveJob format with external class name format.

  ## Options

    * `:queue` - Queue name
    * `:priority` - Priority (default: 0)
    * `:scheduled_at` - When to schedule the job (optional)
    * `:concurrency_key` - Concurrency key (optional)
    * `:labels` - Labels array (optional)

  ## Examples

      # Using Elixir module
      GoodJob.Protocol.enqueue_for_external(MyApp.MyJob, %{id: 1})

      # Using external class name (from external_jobs config)
      GoodJob.Protocol.enqueue_for_external("MyApp::SendEmailJob", %{to: "user@example.com"})
  """
  @spec enqueue_for_external(module() | String.t(), term(), keyword()) ::
          {:ok, GoodJob.Job.t()} | {:error, term()}
  def enqueue_for_external(job_identifier, args, opts \\ []) do
    # Convert job identifier to external class name format
    # If a string is passed, assume it's already the external class name (from external_jobs config lookup)
    # If it contains ::, it's already in external format
    # Otherwise, convert module to external format
    external_class =
      cond do
        is_binary(job_identifier) and String.contains?(job_identifier, "::") ->
          # String is already in external format, use it directly
          job_identifier

        is_binary(job_identifier) ->
          # String is likely already the external class name from external_jobs config
          # Use it as-is (external_jobs config handles the mapping)
          job_identifier

        true ->
          # Atom module, convert to external format
          GoodJob.Protocol.Serialization.module_to_external_class(job_identifier)
      end

    queue_name = Keyword.get(opts, :queue) || "default"

    # Get other options
    priority = Keyword.get(opts, :priority, 0)
    # External GoodJob's `.queued` scope only selects jobs where `scheduled_at <= now`.
    # If `scheduled_at` is NULL, the job will never be considered queued.
    # To match external language behavior (which sets `scheduled_at = created_at` for immediate jobs),
    # default `scheduled_at` to `DateTime.utc_now()` when not explicitly provided.
    scheduled_at = Keyword.get(opts, :scheduled_at) || DateTime.utc_now()
    concurrency_key = Keyword.get(opts, :concurrency_key)
    labels = Keyword.get(opts, :labels)

    # Generate active_job_id
    active_job_id = Ecto.UUID.generate()

    # Serialize in ActiveJob format
    serialized_params =
      GoodJob.Protocol.Serialization.to_active_job(
        job_class: external_class,
        arguments: normalize_args(args),
        queue_name: queue_name,
        priority: priority,
        executions: 0,
        job_id: active_job_id,
        concurrency_key: concurrency_key,
        labels: labels
      )

    # Enqueue the job
    job_attrs = %{
      active_job_id: active_job_id,
      job_class: external_class,
      queue_name: queue_name,
      priority: priority,
      serialized_params: serialized_params,
      scheduled_at: scheduled_at,
      executions_count: 0,
      concurrency_key: concurrency_key,
      labels: labels
    }

    case GoodJob.Job.enqueue(job_attrs) do
      {:ok, job} ->
        # Telemetry.enqueue is now emitted by Job.enqueue/1
        {:ok, job}

      error ->
        error
    end
  end

  @doc """
  Enqueues a job to be processed by Elixir GoodJob.

  The job will be serialized in ActiveJob format with Elixir module name format.

  ## Options

    * `:queue` - Queue name
    * `:priority` - Priority (default: 0)
    * `:scheduled_at` - When to schedule the job (optional)
    * `:concurrency_key` - Concurrency key (optional)
    * `:labels` - Labels array (optional)

  ## Examples

      # Using Elixir module
      GoodJob.Protocol.enqueue_for_elixir(MyApp.MyJob, %{id: 1})

      # Using external class name (will be resolved via external_jobs config)
      GoodJob.Protocol.enqueue_for_elixir("MyApp::SendEmailJob", %{to: "user@example.com"})
  """
  @spec enqueue_for_elixir(module() | String.t(), term(), keyword()) ::
          {:ok, GoodJob.Job.t()} | {:error, term()}
  def enqueue_for_elixir(job_identifier, args, opts \\ []) do
    # Convert job identifier to Elixir module name format
    elixir_module = resolve_elixir_module_name(job_identifier)

    queue_name = Keyword.get(opts, :queue) || "default"

    # Use the standard enqueue function which will handle serialization
    GoodJob.enqueue(elixir_module, normalize_args(args), Keyword.put(opts, :queue, queue_name))
  end

  # Private functions

  defp resolve_elixir_module_name(module) when is_atom(module) do
    module
  end

  defp resolve_elixir_module_name(job_class_string) when is_binary(job_class_string) do
    # First, check explicit configuration mapping (for cross-language jobs from external languages)
    mappings = GoodJob.Config.external_jobs()

    case Map.get(mappings, job_class_string) do
      nil ->
        # Not in config mapping, try automatic resolution (works for Elixir-native jobs)
        resolve_elixir_module_name_automatic(job_class_string)

      module when is_atom(module) ->
        # Found in config mapping, verify module exists
        case Code.ensure_loaded(module) do
          {:module, ^module} ->
            module

          {:error, reason} ->
            raise "Job module configured in external_jobs not found: #{inspect(module)} " <>
                    "for external class #{job_class_string}. Error: #{inspect(reason)}"
        end
    end
  end

  defp resolve_elixir_module_name_automatic(job_class_string) do
    # For Elixir-native jobs, try direct module name resolution first
    # This handles cases where job_class is "MyApp.MyJob" or "Elixir.MyApp.MyJob"
    elixir_string = GoodJob.Protocol.Serialization.external_class_to_module(job_class_string)
    atom_string = if String.starts_with?(elixir_string, "Elixir."), do: elixir_string, else: "Elixir.#{elixir_string}"

    try do
      String.to_existing_atom(atom_string)
    rescue
      ArgumentError ->
        reraise RuntimeError,
                "Job class not found: #{job_class_string}. " <>
                  "For external jobs, configure it in external_jobs config. " <>
                  "For Elixir jobs, ensure the module exists.",
                __STACKTRACE__
    end
  end

  defp normalize_args(args) when is_map(args) do
    # If args is a map, convert to list for ActiveJob compatibility
    # ActiveJob expects arguments as an array
    [args]
  end

  defp normalize_args(args) when is_list(args) do
    args
  end

  defp normalize_args(args) do
    # For other types, wrap in list
    [args]
  end
end
