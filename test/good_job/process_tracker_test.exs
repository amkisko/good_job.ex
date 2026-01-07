defmodule GoodJob.ProcessTrackerTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.Process, as: ProcessSchema
  alias GoodJob.ProcessTracker
  alias GoodJob.Repo

  setup do
    repo = Repo.repo()
    Ecto.Adapters.SQL.Sandbox.checkout(repo)
    Ecto.Adapters.SQL.Sandbox.mode(repo, {:shared, self()})
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo})
    :ok
  end

  test "id_for_lock creates and reuses a process record" do
    pid = start_supervised!({ProcessTracker, name: nil})
    Ecto.Adapters.SQL.Sandbox.allow(Repo.repo(), self(), pid)

    lock_id = GenServer.call(pid, :id_for_lock)
    assert is_binary(lock_id)

    record = Repo.repo().get(ProcessSchema, lock_id)
    assert record

    lock_id_again = GenServer.call(pid, :id_for_lock)
    assert lock_id_again == lock_id
  end

  test "refresh updates record when locks are held" do
    pid = start_supervised!({ProcessTracker, name: nil})
    Ecto.Adapters.SQL.Sandbox.allow(Repo.repo(), self(), pid)
    lock_id = GenServer.call(pid, :id_for_lock)

    send(pid, :refresh)
    Process.sleep(10)

    record = Repo.repo().get(ProcessSchema, lock_id)
    assert record
  end
end
