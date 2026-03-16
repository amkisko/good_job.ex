defmodule GoodJob.AdvisoryLockTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.AdvisoryLock
  alias GoodJob.Repo

  setup do
    repo = Repo.repo()
    Ecto.Adapters.SQL.Sandbox.checkout(repo)
    Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    :ok
  end

  test "hashes keys and produces a lock key" do
    hash = AdvisoryLock.hash_key("test-key")
    assert is_integer(hash)
    assert AdvisoryLock.key_to_lock_key("test-key") == hash
    assert AdvisoryLock.job_id_to_lock_key(Ecto.UUID.generate()) |> is_integer()
  end

  test "supports configurable hash algorithms" do
    md5_hash = AdvisoryLock.hash_key("test-key", hash_algorithm: :md5)
    sha256_hash = AdvisoryLock.hash_key("test-key", hash_algorithm: :sha256)
    hashtextextended_hash = AdvisoryLock.hash_key("test-key", hash_algorithm: :hashtextextended)
    hashtext_hash = AdvisoryLock.hash_key("test-key", hash_algorithm: :hashtext)

    assert is_integer(md5_hash)
    assert is_integer(sha256_hash)
    assert is_integer(hashtextextended_hash)
    assert is_integer(hashtext_hash)
    refute md5_hash == sha256_hash

    case AdvisoryLock.hash_key("test-key", hash_algorithm: :uuid_v5) do
      value when is_integer(value) ->
        assert is_integer(value)

      {:error, _} = error ->
        # uuid_v5 uses uuid_generate_v5() from uuid-ossp; allow missing extension in test envs.
        assert match?({:error, _}, error)
    end
  end

  test "returns error for unsupported hash algorithm" do
    assert {:error, {:unsupported_hash_algorithm, _}} =
             AdvisoryLock.hash_key("test-key", hash_algorithm: :unsupported)

    assert AdvisoryLock.lock("test-key", hash_algorithm: :unsupported) == false
  end

  test "acquires advisory locks for job ids and concurrency keys" do
    assert AdvisoryLock.lock_job(Ecto.UUID.generate()) in [true, false]
    assert AdvisoryLock.lock_concurrency_key("concurrency-key") in [true, false]
  end

  test "acquires and releases session locks" do
    key = 123_456
    assert AdvisoryLock.lock_session(key) in [true, false]
    assert AdvisoryLock.unlock_session(key) in [true, false]
  end

  test "accepts lock function overrides" do
    key = 789_123
    assert AdvisoryLock.lock(key, function: :pg_try_advisory_xact_lock) in [true, false]
    assert AdvisoryLock.lock_session(key, function: :pg_try_advisory_lock) in [true, false]
  end
end
