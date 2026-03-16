defmodule GoodJob.ProcessTest do
  use ExUnit.Case, async: false

  alias GoodJob.{AdvisoryLock, Process, Repo}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "changeset/2" do
    test "creates changeset with valid attributes" do
      changeset = Process.changeset(%Process{}, %{state: %{}, lock_type: 0})
      assert changeset.valid?
    end

    test "allows updating state and lock_type" do
      process = %Process{id: Ecto.UUID.generate()}
      changeset = Process.changeset(process, %{state: %{key: "value"}, lock_type: 1})
      assert changeset.valid?
      assert changeset.changes.state == %{key: "value"}
      assert changeset.changes.lock_type == 1
    end
  end

  describe "find_or_create_record/1" do
    test "creates new record when not found without lock" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      id = Ecto.UUID.generate()
      record = Process.find_or_create_record(id: id, with_advisory_lock: false)
      assert record.id == id
      assert record.state == %{}
      assert record.lock_type == 0
    end

    test "returns existing record when found without lock" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      id = Ecto.UUID.generate()
      record1 = Process.find_or_create_record(id: id, with_advisory_lock: false)
      record2 = Process.find_or_create_record(id: id, with_advisory_lock: false)
      assert record1.id == record2.id
    end

    test "creates new record with advisory lock" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      id = Ecto.UUID.generate()
      {:ok, record} = Process.find_or_create_record(id: id, with_advisory_lock: true)
      assert record.id == id
      assert record.state == %{}
      assert record.lock_type == 1
    end

    test "returns existing record with advisory lock" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      id = Ecto.UUID.generate()
      {:ok, record1} = Process.find_or_create_record(id: id, with_advisory_lock: true)
      {:ok, record2} = Process.find_or_create_record(id: id, with_advisory_lock: true)
      assert record1.id == record2.id
    end
  end

  describe "active/inactive" do
    test "classifies advisory-locked process as active" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      id = Ecto.UUID.generate()
      {:ok, record} = Process.find_or_create_record(id: id, with_advisory_lock: true)

      active_ids =
        Process.active()
        |> Repo.repo().all()
        |> Enum.map(& &1.id)

      inactive_ids =
        Process.inactive()
        |> Repo.repo().all()
        |> Enum.map(& &1.id)

      assert record.id in active_ids
      refute record.id in inactive_ids

      lock_key = AdvisoryLock.hash_key(id)
      assert AdvisoryLock.unlock_session(lock_key) in [true, false]
    end
  end
end
