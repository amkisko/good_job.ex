defmodule GoodJob.AdvisoryLock do
  @moduledoc """
  Functions for PostgreSQL advisory locks.

  Advisory locks are used to ensure jobs are only executed once,
  even across multiple processes.
  """

  @default_lock_function :pg_try_advisory_xact_lock
  @default_session_lock_function :pg_try_advisory_lock
  @supported_hash_algorithms ~w(
    md5
    sha1
    sha224
    sha256
    sha384
    sha512
    hashtextextended
    hashtext
    uuid_v5
  )
  @supported_lock_functions ~w(
    pg_try_advisory_xact_lock
    pg_advisory_xact_lock
    pg_try_advisory_lock
    pg_advisory_lock
  )

  @doc """
  Acquires an advisory lock for a job ID.

  Returns `true` if the lock was acquired, `false` otherwise.
  """
  def lock_job(job_id, opts \\ []) when is_binary(job_id) do
    lock(job_id, opts)
  end

  @doc """
  Acquires an advisory lock for a concurrency key.

  Returns `true` if the lock was acquired, `false` otherwise.
  """
  def lock_concurrency_key(key, opts \\ []) when is_binary(key) do
    lock(key, opts)
  end

  @doc """
  Acquires an advisory lock using a numeric or text key.

  For numeric keys, uses a configurable advisory lock function.
  For text keys, converts the text to a hash for use with advisory locks.
  """
  def lock(key, opts \\ [])

  def lock(key, opts) when is_integer(key) do
    repo = GoodJob.Repo.repo()
    function = transaction_lock_function(opts)

    try do
      result = Ecto.Adapters.SQL.query!(repo, "SELECT #{function}($1)", [key])

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

  def lock(key, opts) when is_binary(key) do
    case hash_key(key, opts) do
      lock_key when is_integer(lock_key) ->
        lock(lock_key, opts)

      {:error, _} = error ->
        require Logger

        Logger.error("GoodJob AdvisoryLock: Error hashing lock key #{inspect(key)}: #{inspect(error)}")
        GoodJob.Telemetry.lock_failed(key, :transaction)
        false
    end
  end

  @doc """
  Converts a job ID (UUID) to a lock key.
  """
  def job_id_to_lock_key(job_id, opts \\ []) when is_binary(job_id) do
    hash_key(job_id, opts)
  end

  @doc """
  Converts a text key to a lock key.
  """
  def key_to_lock_key(key, opts \\ []) when is_binary(key) do
    hash_key(key, opts)
  end

  @doc """
  Hashes a key to an integer for use with advisory locks.

  Uses the configured digest algorithm and projects to bigint with:
  ('x'||substr(<hex>,1,16))::bit(64)::bigint
  """
  def hash_key(key, opts \\ []) when is_binary(key) do
    repo = GoodJob.Repo.repo()
    hash_algorithm = hash_algorithm(opts)

    case normalize_hash_algorithm(hash_algorithm) do
      {:ok, normalized_hash_algorithm} ->
        lock_key_sql = lock_key_expression_sql(normalized_hash_algorithm)
        sql = "SELECT #{lock_key_sql}"

        case repo.query(sql, [key]) do
          {:ok, %{rows: [[hash]]}} -> hash
          {:error, _} = error -> error
        end

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Acquires a session-level advisory lock.

  This lock persists until explicitly released or the session ends.
  """
  def lock_session(key, opts \\ []) when is_integer(key) do
    repo = GoodJob.Repo.repo()
    function = session_lock_function(opts)

    case repo.query("SELECT #{function}($1)", [key]) do
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

  defp transaction_lock_function(opts) do
    function =
      opts[:function] ||
        GoodJob.Config.advisory_lock_function() ||
        @default_lock_function

    normalize_lock_function(function)
  end

  defp session_lock_function(opts) do
    function = opts[:function] || @default_session_lock_function
    normalize_lock_function(function)
  end

  defp hash_algorithm(opts) do
    opts[:hash_algorithm] ||
      GoodJob.Config.advisory_lock_hash_algorithm()
  end

  defp normalize_lock_function(function) do
    normalized_function = function |> to_string() |> String.downcase()

    if normalized_function in @supported_lock_functions do
      normalized_function
    else
      raise ArgumentError,
            "Unsupported advisory lock function: #{inspect(function)}. " <>
              "Supported values are: #{Enum.join(@supported_lock_functions, ", ")}"
    end
  end

  defp normalize_hash_algorithm(hash_algorithm) do
    normalized_hash_algorithm = hash_algorithm |> to_string() |> String.downcase()

    if normalized_hash_algorithm in @supported_hash_algorithms do
      {:ok, normalized_hash_algorithm}
    else
      {:error,
       {:unsupported_hash_algorithm,
        "Unsupported advisory lock hash algorithm: #{inspect(hash_algorithm)}. " <>
          "Supported values are: #{Enum.join(@supported_hash_algorithms, ", ")}"}}
    end
  end

  defp lock_key_expression_sql("hashtextextended"), do: "hashtextextended($1::text, 0)"

  defp lock_key_expression_sql("hashtext") do
    "((hashtext($1::text)::bigint << 32) + (hashtext(('good_job-' || $1::text))::bigint & 4294967295::bigint))"
  end

  defp lock_key_expression_sql("uuid_v5") do
    "('x' || substr(replace(uuid_generate_v5('6ba7b810-9dad-11d1-80b4-00c04fd430c8'::uuid, $1::text)::text, '-', ''), 1, 16))::bit(64)::bigint"
  end

  defp lock_key_expression_sql("md5"), do: "('x' || substr(md5($1::text), 1, 16))::bit(64)::bigint"

  defp lock_key_expression_sql(algorithm) do
    "('x' || substr(encode(digest($1::text, '#{algorithm}'), 'hex'), 1, 16))::bit(64)::bigint"
  end
end
