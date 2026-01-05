defmodule GoodJob.Cron.EntryTest do
  use ExUnit.Case, async: false

  alias GoodJob.Cron.Entry

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(_args) do
      :ok
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(GoodJob.Repo.repo())
    :ok
  end

  describe "new/1" do
    test "creates entry with required fields" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      assert entry.key == "test"
      assert entry.cron == "0 * * * *"
      assert entry.class == TestJob
    end

    test "creates entry with optional fields" do
      entry =
        Entry.new(
          key: "test",
          cron: "0 * * * *",
          class: TestJob,
          args: %{test: "value"},
          queue: "custom",
          priority: 5,
          enabled: false
        )

      assert entry.args == %{test: "value"}
      assert entry.queue == "custom"
      assert entry.priority == 5
      assert entry.enabled == false
    end

    test "uses defaults for optional fields" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      assert entry.args == %{}
      assert entry.queue == "default"
      assert entry.priority == 0
      assert entry.enabled == true
    end

    test "raises for invalid cron expression" do
      assert_raise ArgumentError, fn ->
        Entry.new(key: "test", cron: "invalid", class: TestJob)
      end
    end

    test "raises for invalid class" do
      assert_raise ArgumentError, fn ->
        Entry.new(key: "test", cron: "0 * * * *", class: :NonExistentModule)
      end
    end

    test "handles binary class name" do
      # Test the case where class is a binary string (without Elixir. prefix)
      # The code prepends "Elixir." to binary class names for validation
      # but stores the original binary in the struct
      entry = Entry.new(key: "test", cron: "0 * * * *", class: "String")
      # The struct stores the binary as-is, not converted to atom
      assert entry.class == "String"
    end
  end

  describe "next_at/2" do
    test "calculates next execution time" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      now = DateTime.utc_now()
      next = Entry.next_at(entry, now)
      assert DateTime.compare(next, now) == :gt
    end

    test "uses provided time as base" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      base = ~U[2024-01-01 12:00:00Z]
      next = Entry.next_at(entry, base)
      assert DateTime.compare(next, base) == :gt
    end
  end

  describe "enqueue/2" do
    test "enqueues job when enabled" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob, enabled: true)
      cron_at = DateTime.utc_now()
      result = Entry.enqueue(entry, cron_at)
      assert match?({:ok, _}, result)
    end

    test "skips when disabled" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob, enabled: false)
      cron_at = DateTime.utc_now()
      assert Entry.enqueue(entry, cron_at) == {:ok, :disabled}
    end
  end

  describe "within/3" do
    test "finds scheduled times in range" do
      entry = Entry.new(key: "test", cron: "0 * * * *", class: TestJob)
      start = ~U[2024-01-01 00:00:00Z]
      finish = ~U[2024-01-01 02:00:00Z]
      times = Entry.within(entry, start, finish)
      assert times != []
    end
  end
end
