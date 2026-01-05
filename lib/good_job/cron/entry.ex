defmodule GoodJob.Cron.Entry do
  @moduledoc """
  Represents a cron job entry with its schedule and configuration.
  """

  alias GoodJob.Cron.Expression
  import Ecto.Query

  @type t :: %__MODULE__{
          key: String.t(),
          cron: String.t(),
          class: module(),
          args: map(),
          queue: String.t(),
          priority: integer(),
          enabled: boolean(),
          expression: Expression.t()
        }

  defstruct [
    :key,
    :cron,
    :class,
    :args,
    :queue,
    :priority,
    :enabled,
    :expression
  ]

  @doc """
  Creates a new cron entry from configuration.

  Validates the cron expression and raises if invalid.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    key = Keyword.fetch!(opts, :key)
    cron = Keyword.fetch!(opts, :cron)
    class = Keyword.fetch!(opts, :class)

    {:ok, expression} =
      case Expression.parse(cron) do
        {:ok, expr} ->
          {:ok, expr}

        {:error, reason} ->
          raise ArgumentError,
                "Invalid cron format for key '#{key}': '#{cron}'. Error: #{inspect(reason)}"
      end

    class_atom = if is_binary(class), do: String.to_existing_atom("Elixir.#{class}"), else: class

    case Code.ensure_loaded(class_atom) do
      {:module, _} ->
        :ok

      {:error, _} ->
        raise ArgumentError,
              "Cron entry '#{key}' references invalid job class: #{inspect(class)}"
    end

    args = Keyword.get(opts, :args, %{})
    queue = Keyword.get(opts, :queue, "default")
    priority = Keyword.get(opts, :priority, 0)
    enabled = Keyword.get(opts, :enabled, true)

    %__MODULE__{
      key: to_string(key),
      cron: cron,
      class: class,
      args: args,
      queue: queue,
      priority: priority,
      enabled: enabled,
      expression: expression
    }
  end

  @doc """
  Returns the next scheduled time for this cron entry.
  """
  @spec next_at(t(), DateTime.t() | nil) :: DateTime.t()
  def next_at(%__MODULE__{expression: expr}, previously_at \\ nil) do
    base_time = previously_at || DateTime.utc_now()
    Expression.next_at(expr, base_time)
  end

  @doc """
  Enqueues a job for this cron entry at the given time.
  """
  @spec enqueue(t(), DateTime.t()) :: {:ok, any()} | {:error, any()}
  def enqueue(%__MODULE__{} = entry, cron_at) do
    enabled = entry.enabled && GoodJob.SettingManager.cron_key_enabled?(entry.key)

    if enabled do
      cron_key = entry.key
      repo = GoodJob.Repo.repo()

      existing =
        repo.one(
          from(j in GoodJob.Job,
            where: j.cron_key == ^cron_key and j.cron_at == ^cron_at and is_nil(j.finished_at),
            limit: 1
          )
        )

      if existing do
        {:ok, :duplicate}
      else
        GoodJob.enqueue(entry.class, entry.args,
          queue: entry.queue,
          priority: entry.priority,
          scheduled_at: cron_at
        )
        |> case do
          {:ok, job} ->
            job
            |> GoodJob.Job.changeset(%{cron_key: cron_key, cron_at: cron_at})
            |> repo.update()

          error ->
            error
        end
      end
    else
      {:ok, :disabled}
    end
  end

  @doc """
  Returns all scheduled times within a time period.
  """
  @spec within(t(), DateTime.t(), DateTime.t()) :: [DateTime.t()]
  def within(%__MODULE__{expression: expr}, start_time, end_time) do
    Stream.unfold(start_time, fn current ->
      next = Expression.next_at(expr, current)

      if DateTime.compare(next, end_time) != :gt do
        {next, next}
      else
        nil
      end
    end)
    |> Enum.to_list()
  end
end
