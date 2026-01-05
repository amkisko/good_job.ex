defmodule GoodJob.Job do
  @moduledoc """
  Ecto schema for good_jobs table.

  Represents a job in the queue.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias GoodJob.Job.{Instance, Query, State}

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "good_jobs" do
    field(:queue_name, :string)
    field(:priority, :integer)
    field(:serialized_params, :map)
    field(:scheduled_at, :utc_datetime_usec)
    field(:performed_at, :utc_datetime_usec)
    field(:finished_at, :utc_datetime_usec)
    field(:error, :string)
    field(:active_job_id, :binary_id)
    field(:concurrency_key, :string)
    field(:cron_key, :string)
    field(:retried_good_job_id, :binary_id)
    field(:cron_at, :utc_datetime_usec)
    field(:batch_id, :binary_id)
    field(:batch_callback_id, :binary_id)
    field(:is_discrete, :boolean)
    field(:executions_count, :integer, default: 0)
    field(:job_class, :string)
    field(:error_event, :integer)
    field(:labels, {:array, :string})
    field(:locked_by_id, :binary_id)
    field(:locked_at, :utc_datetime_usec)

    field(:inserted_at, :utc_datetime_usec, source: :created_at, autogenerate: {DateTime, :utc_now, []})
    field(:updated_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []})
  end

  # Delegate query functions to Job.Query for backward compatibility
  # Using wrapper functions instead of defdelegate to handle default arguments correctly
  def unfinished(query \\ __MODULE__), do: Query.unfinished(query)
  def finished(query \\ __MODULE__), do: Query.finished(query)
  def unlocked(query \\ __MODULE__), do: Query.unlocked(query)
  def locked(query \\ __MODULE__), do: Query.locked(query)
  def in_queue(query \\ __MODULE__, queue_name), do: Query.in_queue(query, queue_name)
  def scheduled_before(query \\ __MODULE__, datetime), do: Query.scheduled_before(query, datetime)
  def finished_before(query \\ __MODULE__, datetime), do: Query.finished_before(query, datetime)
  def with_concurrency_key(query \\ __MODULE__, key), do: Query.with_concurrency_key(query, key)

  def order_for_candidate_lookup(query \\ __MODULE__, parsed_queues \\ %{}),
    do: Query.order_for_candidate_lookup(query, parsed_queues)

  def in_batch(query \\ __MODULE__, batch_id), do: Query.in_batch(query, batch_id)
  def running(query \\ __MODULE__), do: Query.running(query)
  def queued(query \\ __MODULE__), do: Query.queued(query)
  @spec succeeded(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def succeeded(query \\ __MODULE__), do: Query.succeeded(query)
  @spec discarded(Ecto.Query.t() | module()) :: Ecto.Query.t()
  def discarded(query \\ __MODULE__), do: Query.discarded(query)
  def scheduled(query \\ __MODULE__), do: Query.scheduled(query)
  def with_label(query \\ __MODULE__, label), do: Query.with_label(query, label)
  def with_any_label(query \\ __MODULE__, labels), do: Query.with_any_label(query, labels)
  def with_all_labels(query \\ __MODULE__, labels), do: Query.with_all_labels(query, labels)
  def with_labels(query \\ __MODULE__, labels), do: Query.with_labels(query, labels)
  def dequeueing_ordered(query \\ __MODULE__), do: Query.dequeueing_ordered(query)
  def only_scheduled(query \\ __MODULE__), do: Query.only_scheduled(query)
  def exclude_paused(query \\ __MODULE__), do: Query.exclude_paused(query)
  def with_job_class(query \\ __MODULE__, job_class), do: Query.with_job_class(query, job_class)
  def with_batch_id(query \\ __MODULE__, batch_id), do: Query.with_batch_id(query, batch_id)
  def created_after(query \\ __MODULE__, datetime), do: Query.created_after(query, datetime)
  def created_before(query \\ __MODULE__, datetime), do: Query.created_before(query, datetime)
  def with_priority(query \\ __MODULE__, priority), do: Query.with_priority(query, priority)
  def with_min_priority(query \\ __MODULE__, min_priority), do: Query.with_min_priority(query, min_priority)
  def with_max_priority(query \\ __MODULE__, max_priority), do: Query.with_max_priority(query, max_priority)
  def with_errors(query \\ __MODULE__), do: Query.with_errors(query)
  def without_errors(query \\ __MODULE__), do: Query.without_errors(query)
  def with_cron_key(query \\ __MODULE__, cron_key), do: Query.with_cron_key(query, cron_key)
  def order_by_created_desc(query \\ __MODULE__), do: Query.order_by_created_desc(query)
  def order_by_created_asc(query \\ __MODULE__), do: Query.order_by_created_asc(query)
  def order_by_scheduled_asc(query \\ __MODULE__), do: Query.order_by_scheduled_asc(query)
  def order_by_finished_desc(query \\ __MODULE__), do: Query.order_by_finished_desc(query)

  # Delegate state calculation to Job.State
  defdelegate calculate_state(job), to: State, as: :calculate

  # Delegate find functions (these need special handling)
  def find_by_id(id) do
    GoodJob.Repo.repo().get(__MODULE__, id)
  end

  def find_by_active_job_id(active_job_id) do
    GoodJob.Repo.repo().get_by(__MODULE__, active_job_id: active_job_id)
  end

  @doc """
  Creates a changeset for a job.
  """
  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :queue_name,
      :priority,
      :serialized_params,
      :scheduled_at,
      :performed_at,
      :finished_at,
      :error,
      :active_job_id,
      :concurrency_key,
      :cron_key,
      :retried_good_job_id,
      :cron_at,
      :batch_id,
      :batch_callback_id,
      :is_discrete,
      :executions_count,
      :job_class,
      :error_event,
      :labels,
      :locked_by_id,
      :locked_at
    ])
    |> validate_required([:active_job_id])
  end

  @doc """
  Builds a job for enqueueing.
  """
  def build_for_enqueue(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @doc """
  Enqueues a job.
  """
  def enqueue(attrs) do
    repo = GoodJob.Repo.repo()

    case %__MODULE__{}
         |> changeset(attrs)
         |> repo.insert() do
      {:ok, job} = result ->
        # Emit events for UI updates (PubSub) and observability (Telemetry)
        GoodJob.PubSub.broadcast(:job_created, job.id)
        GoodJob.Telemetry.enqueue(job)

        if GoodJob.Config.enable_listen_notify?() do
          now = DateTime.utc_now()
          should_notify = is_nil(job.scheduled_at) or DateTime.compare(job.scheduled_at, now) != :gt

          if should_notify do
            notification = GoodJob.Protocol.Notification.for_job(job)
            GoodJob.Notifier.notify(notification)
          end
        end

        result

      error ->
        error
    end
  end

  @doc """
  Deletes a job from the database.
  """
  def delete(job) do
    case GoodJob.Repo.repo().delete(job) do
      {:ok, deleted_job} = result ->
        GoodJob.PubSub.broadcast(:job_deleted, deleted_job.id)
        GoodJob.Telemetry.job_delete(deleted_job)
        result

      error ->
        error
    end
  end

  @doc """
  Retries a discarded job by clearing its finished_at and error fields.
  """
  def retry(job) do
    repo = GoodJob.Repo.repo()
    fresh_job = repo.get(__MODULE__, job.id)

    if is_nil(fresh_job) do
      {:error, :not_found}
    else
      case fresh_job
           |> changeset(%{
             finished_at: nil,
             error: nil,
             performed_at: nil,
             locked_by_id: nil,
             locked_at: nil,
             scheduled_at: DateTime.utc_now()
           })
           |> repo.update() do
        {:ok, retried_job} = result ->
          GoodJob.PubSub.broadcast(:job_retried, retried_job.id)
          GoodJob.Telemetry.job_retry_manual(retried_job)
          result

        error ->
          error
      end
    end
  end

  # Macro functionality for `use GoodJob.Job`
  defmacro __using__(opts \\ []) do
    queue = Keyword.get(opts, :queue, "default")
    priority = Keyword.get(opts, :priority, 0)
    max_attempts = Keyword.get(opts, :max_attempts, 5)
    timeout = Keyword.get(opts, :timeout, :infinity)
    tags = Keyword.get(opts, :tags, [])

    quote bind_quoted: [queue: queue, priority: priority, max_attempts: max_attempts, timeout: timeout, tags: tags] do
      @behaviour GoodJob.Behaviour

      @compile {:no_warn_undefined, [Module]}
      @discard_on_exceptions []

      def __good_job_queue__, do: unquote(queue)
      def __good_job_priority__, do: unquote(priority)
      def __good_job_max_attempts__, do: unquote(max_attempts)
      def __good_job_timeout__, do: unquote(timeout)
      def __good_job_tags__, do: unquote(tags)

      def enqueue(args, opts \\ []) do
        default_opts = [
          queue: __good_job_queue__(),
          priority: __good_job_priority__(),
          tags: __good_job_tags__()
        ]

        opts = Keyword.merge(default_opts, opts)
        GoodJob.enqueue(__MODULE__, args, opts)
      end

      def perform_now(args \\ %{}) do
        default_opts = [
          queue: __good_job_queue__(),
          priority: __good_job_priority__(),
          tags: __good_job_tags__(),
          execution_mode: :inline
        ]

        case GoodJob.enqueue(__MODULE__, args, default_opts) do
          {:ok, _job} = result -> result
          {:error, _} = error -> error
        end
      end

      @doc """
      Enqueues the job for later execution (ActiveJob-style API).

      You can override this function with pattern matching to validate arguments:

          defmodule MyApp.SendEmailJob do
            use GoodJob.Job

            # Override with pattern matching for argument validation
            def perform_later(%{to: to, subject: subject}) when is_binary(to) and is_binary(subject) do
              super(%{to: to, subject: subject})
            end
          end

      This ensures arguments are validated before the job is enqueued to the database.
      """
      def perform_later(args \\ %{}) do
        default_opts = [
          queue: __good_job_queue__(),
          priority: __good_job_priority__(),
          tags: __good_job_tags__()
        ]

        GoodJob.enqueue(__MODULE__, args, default_opts)
      end

      defoverridable perform_later: 1

      def set(options \\ []) do
        GoodJob.ConfiguredJob.new(__MODULE__, options)
      end

      def new(args \\ %{}, options \\ []) do
        Instance.new(__MODULE__, args, options)
      end

      def backoff(attempt) do
        # Default to constant 3 seconds to match Ruby GoodJob's ActiveJob default
        GoodJob.Backoff.constant(attempt)
      end

      def max_attempts do
        __good_job_max_attempts__()
      end

      def good_job_concurrency_config do
        []
      end

      defoverridable backoff: 1, max_attempts: 0, good_job_concurrency_config: 0

      defmacro discard_on(exception_or_list) do
        exceptions =
          case exception_or_list do
            list when is_list(list) -> list
            single -> [single]
          end

        quote do
          @discard_on_exceptions unquote(exceptions)
        end
      end

      def __good_job_discard_on__ do
        case Module.__info__(__MODULE__, :attributes) do
          attributes when is_list(attributes) ->
            case Keyword.get(attributes, :discard_on_exceptions) do
              nil -> []
              [{list}] when is_list(list) -> List.flatten(list)
              [{other}] -> [other]
              _ -> []
            end

          _ ->
            []
        end
      rescue
        _ -> []
      catch
        _, _ -> []
      end
    end
  end
end
