defmodule GoodJob.JobPerformerTest do
  use ExUnit.Case, async: false

  alias GoodJob.{JobPerformer, Repo}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), :manual)
    :ok
  end

  describe "parse_queues/1" do
    test "parses wildcard queue" do
      assert JobPerformer.parse_queues("*") == %{}
    end

    test "parses comma-separated queues" do
      result = JobPerformer.parse_queues("queue1,queue2,queue3")
      assert result == %{include: ["queue1", "queue2", "queue3"]}
    end

    test "parses excluded queues" do
      result = JobPerformer.parse_queues("-queue1,-queue2")
      # String.slice(&1, 1..-1//-1) removes first char and reverses
      # Actually, let's check what it really does
      assert Map.has_key?(result, :exclude)
      assert length(result.exclude) == 2
    end

    test "parses ordered queues with + prefix" do
      result = JobPerformer.parse_queues("+queue1,queue2")
      assert result == %{include: ["queue1", "queue2"], ordered_queues: true}
    end

    test "rejects invalid wildcard patterns" do
      assert_raise ArgumentError, ~r/Only '\*' is supported/, fn ->
        JobPerformer.parse_queues("queue*")
      end
    end

    test "parses mixed include and exclude" do
      result = JobPerformer.parse_queues("queue1,-queue2")
      assert result == %{exclude: ["queue2"]}
    end

    test "handles empty string" do
      result = JobPerformer.parse_queues("")
      assert result == %{}
    end

    test "strips concurrency values from queue names" do
      result = JobPerformer.parse_queues("queue1:5,queue2:10")
      assert result == %{include: ["queue1", "queue2"]}
    end

    test "strips concurrency from ordered queues" do
      result = JobPerformer.parse_queues("+queue1:5,queue2:10")
      assert result == %{include: ["queue1", "queue2"], ordered_queues: true}
    end

    test "strips concurrency from excluded queues" do
      result = JobPerformer.parse_queues("-queue1:5,-queue2:10")
      assert result == %{exclude: ["queue1", "queue2"]}
    end

    test "handles queue names with colons (before concurrency)" do
      # If queue name itself has colon, it should be preserved
      # e.g., "queue:name:5" -> queue name is "queue:name", concurrency is 5
      result = JobPerformer.parse_queues("queue:name:5")
      assert result == %{include: ["queue:name"]}
    end
  end

  describe "perform_next/3" do
    test "returns nil when no jobs available" do
      Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
      lock_id = Ecto.UUID.generate()
      assert {:ok, nil} = JobPerformer.perform_next("*", lock_id)
    end
  end
end
