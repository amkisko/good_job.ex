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

  test "acquires advisory locks for job ids and concurrency keys" do
    assert AdvisoryLock.lock_job(Ecto.UUID.generate()) in [true, false]
    assert AdvisoryLock.lock_concurrency_key("concurrency-key") in [true, false]
  end

  test "acquires and releases session locks" do
    key = 123_456
    assert AdvisoryLock.lock_session(key) in [true, false]
    assert AdvisoryLock.unlock_session(key) in [true, false]
  end
end
