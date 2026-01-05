defmodule GoodJob.RepoTest do
  use ExUnit.Case, async: false

  alias GoodJob.Repo

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    :ok
  end

  describe "repo/0" do
    test "returns configured repository" do
      repo = Repo.repo()
      assert repo == GoodJob.TestRepo
    end
  end

  describe "query/2" do
    test "executes query" do
      result = Repo.query("SELECT 1 as value")
      assert result.num_rows == 1
      assert List.first(result.rows) == [1]
    end

    test "executes query with parameters" do
      result = Repo.query("SELECT $1::integer as value", [42])
      assert result.num_rows == 1
      assert List.first(result.rows) == [42]
    end
  end

  describe "query_one/2" do
    test "returns first value from first row" do
      value = Repo.query_one("SELECT 42 as value")
      assert value == 42
    end

    test "returns nil for empty result" do
      value = Repo.query_one("SELECT 1 WHERE false")
      assert value == nil
    end

    test "handles query errors" do
      result = Repo.query_one("SELECT * FROM nonexistent_table")
      assert {:error, _} = result
    end
  end
end
