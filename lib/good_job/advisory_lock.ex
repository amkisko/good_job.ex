defmodule GoodJob.AdvisoryLock do
  @moduledoc """
  Functions for PostgreSQL advisory locks.

  Advisory locks are used to ensure jobs are only executed once,
  even across multiple processes.
  """

  @doc """
  Acquires an advisory lock for a job ID.

  Returns `true` if the lock was acquired, `false` otherwise.
  """
  def lock_job(job_id) when is_binary(job_id) do
    lock_key = job_id_to_lock_key(job_id)
    lock(lock_key)
  end

  @doc """
  Acquires an advisory lock for a concurrency key.

  Returns `true` if the lock was acquired, `false` otherwise.
  """
  def lock_concurrency_key(key) when is_binary(key) do
    lock_key = key_to_lock_key(key)
    lock(lock_key)
  end

  @doc """
  Acquires an advisory lock using a numeric or text key.

  For numeric keys, uses `pg_try_advisory_xact_lock` which is automatically released
  when the transaction commits or rolls back.
  For text keys, converts the text to a hash for use with advisory locks.
  """
  def lock(key) when is_integer(key) do
    repo = GoodJob.Repo.repo()

    try do
      # Use Ecto.Adapters.SQL.query! to ensure we use the transaction connection
      result = Ecto.Adapters.SQL.query!(repo, "SELECT pg_try_advisory_xact_lock($1)", [key])

      case result.rows do
        [[true]] ->
          GoodJob.Telemetry.lock_acquired(key, :transaction)
          true

        [[false]] ->
          GoodJob.Telemetry.lock_failed(key, :transaction)
          false

        _ ->
          require Logger
          Logger.error("GoodJob AdvisoryLock: Unexpected result for key #{key}: #{inspect(result)}")
          GoodJob.Telemetry.lock_failed(key, :transaction)
          false
      end
    rescue
      error ->
        require Logger
        Logger.error("GoodJob AdvisoryLock: Error acquiring lock for key #{key}: #{inspect(error)}")
        GoodJob.Telemetry.lock_failed(key, :transaction)
        false
    end
  end

  def lock(key) when is_binary(key) do
    lock_key = hash_key(key)
    lock(lock_key)
  end

  @doc """
  Converts a job ID (UUID) to a lock key.

  Uses the first 8 bytes of the UUID as a bigint for the lock key.
  """
  def job_id_to_lock_key(job_id) when is_binary(job_id) do
    # Convert UUID to lock key
    # PostgreSQL advisory locks use bigint, so we hash the UUID
    hash_key(job_id)
  end

  @doc """
  Converts a text key to a lock key.
  """
  def key_to_lock_key(key) when is_binary(key) do
    hash_key(key)
  end

  @doc """
  Hashes a key to an integer for use with advisory locks.

  Uses PostgreSQL's hashtext function to convert text to a hash.
  """
  def hash_key(key) when is_binary(key) do
    repo = GoodJob.Repo.repo()

    case repo.query("SELECT hashtext($1)", [key]) do
      {:ok, %{rows: [[hash]]}} -> hash
      {:error, _} = error -> error
    end
  end

  @doc """
  Acquires a session-level advisory lock.

  This lock persists until explicitly released or the session ends.
  """
  def lock_session(key) when is_integer(key) do
    repo = GoodJob.Repo.repo()

    case repo.query("SELECT pg_try_advisory_lock($1)", [key]) do
      {:ok, %{rows: [[true]]}} -> true
      {:ok, %{rows: [[false]]}} -> false
      {:error, _} = error -> error
    end
  end

  @doc """
  Releases a session-level advisory lock.
  """
  def unlock_session(key) when is_integer(key) do
    repo = GoodJob.Repo.repo()

    case repo.query("SELECT pg_advisory_unlock($1)", [key]) do
      {:ok, %{rows: [[true]]}} -> true
      {:ok, %{rows: [[false]]}} -> false
      {:error, _} = error -> error
    end
  end
end
