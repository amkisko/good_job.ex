defmodule GoodJob.Backoff do
  @moduledoc """
  Provides backoff calculation strategies for job retries.

  This module calculates the delay (in seconds) before retrying a failed job.
  It does NOT handle retry logic itself - that's handled by the job retry/discard system.

  Aligned with Ruby GoodJob's ActiveJob retry behavior:
  - Default: Constant 3 seconds (matches Ruby GoodJob's `retry_on` default)
  - Supports exponential, linear, constant, and polynomial backoff
  - Default jitter: 15% (0.15) to match Ruby GoodJob's ActiveJob default

  ## How It Works

  When a job fails and the retry system decides to retry it:
  1. The job's `backoff/1` callback (or default) is called to calculate the delay
  2. The job is rescheduled with `scheduled_at = now + backoff_seconds`
  3. The scheduler picks up the job when `scheduled_at` is reached

  This is separate from the retry/discard decision logic, which determines
  whether a job should be retried at all.
  """

  # Default values aligned with Ruby GoodJob/ActiveJob
  @default_mult 2.0
  @default_base 1
  @default_constant_base 3
  @default_max 100
  @default_jitter 0.15

  @doc """
  Calculates exponential backoff with jitter.

  ## Examples

      iex> GoodJob.Backoff.exponential(1)
      2

      iex> GoodJob.Backoff.exponential(3)
      8
  """
  @spec exponential(integer(), keyword()) :: integer()
  def exponential(attempt, opts \\ []) when is_integer(attempt) and attempt > 0 do
    mult = Keyword.get(opts, :mult, @default_mult)
    base = Keyword.get(opts, :base, @default_base)
    max_delay = Keyword.get(opts, :max, @default_max)
    # Exponential backoff doesn't apply jitter by default (only when explicitly requested)
    jitter = Keyword.get(opts, :jitter, 0.0)

    # Formula: base * mult^attempt
    delay = trunc(base * :math.pow(mult, attempt))
    delay = min(delay, max_delay)

    if jitter > 0.0 do
      add_jitter(delay, jitter)
    else
      delay
    end
  end

  @doc """
  Calculates constant backoff.

  This is the default strategy for Ruby GoodJob (ActiveJob's `retry_on` default wait: 3 seconds).

  ## Examples

      iex> GoodJob.Backoff.constant(1)
      3

      iex> GoodJob.Backoff.constant(3)
      3

      iex> GoodJob.Backoff.constant(1, base: 5)
      5
  """
  @spec constant(integer(), keyword()) :: integer()
  def constant(_attempt, opts \\ []) do
    base = Keyword.get(opts, :base, @default_constant_base)
    jitter = Keyword.get(opts, :jitter, @default_jitter)

    if jitter > 0.0 do
      add_jitter(base, jitter)
    else
      base
    end
  end

  @doc """
  Calculates linear backoff.

  ## Examples

      iex> GoodJob.Backoff.linear(1, base: 5)
      5

      iex> GoodJob.Backoff.linear(3, base: 5)
      15
  """
  @spec linear(integer(), keyword()) :: integer()
  def linear(attempt, opts \\ []) when is_integer(attempt) and attempt > 0 do
    base = Keyword.get(opts, :base, @default_base)
    base * attempt
  end

  @doc """
  Calculates polynomial backoff (matches Ruby ActiveJob's `:polynomially_longer`).

  Formula: `((executions^4) + (rand * executions^4 * jitter)) + 2`

  This matches Ruby ActiveJob's polynomial backoff strategy.

  ## Examples

      iex> delay = GoodJob.Backoff.polynomial(1)
      ...> delay >= 2 and delay <= 3
      true

      iex> delay = GoodJob.Backoff.polynomial(2)
      ...> delay >= 18 and delay <= 19
      true
  """
  @spec polynomial(integer(), keyword()) :: integer()
  def polynomial(executions, opts \\ []) when is_integer(executions) and executions > 0 do
    jitter = Keyword.get(opts, :jitter, @default_jitter)
    executions_pow4 = :math.pow(executions, 4) |> trunc()

    # Base polynomial: executions^4 + 2
    base_delay = executions_pow4 + 2

    # Add jitter: rand * executions^4 * jitter
    if jitter > 0.0 do
      jitter_amount = trunc(executions_pow4 * jitter)
      random_jitter = if jitter_amount > 0, do: :rand.uniform(jitter_amount), else: 0
      max(1, base_delay + random_jitter)
    else
      max(1, base_delay)
    end
  end

  @doc """
  Adds jitter to a delay value.

  Uses additive-only jitter calculation (rand * delay * jitter), matching Ruby GoodJob's behavior.
  Default jitter is 15% (0.15) to match Ruby ActiveJob's default.

  ## Examples

      iex> jittered = GoodJob.Backoff.add_jitter(100, 0.15)
      ...> jittered >= 100 and jittered <= 115
      true
  """
  @spec add_jitter(integer(), float()) :: integer()
  def add_jitter(delay, jitter) when is_float(jitter) and jitter > 0 do
    jitter_amount = trunc(delay * jitter)

    # Avoid calling :rand.uniform(0) which is invalid
    if jitter_amount > 0 do
      # Additive-only jitter (rand * delay * jitter) - matches Ruby Kernel.rand * delay * jitter
      random_jitter = :rand.uniform(jitter_amount)
      max(1, delay + random_jitter)
    else
      # If jitter_amount is 0, just return the delay (at least 1)
      max(1, delay)
    end
  end

  def add_jitter(delay, _jitter), do: max(1, delay)
end
