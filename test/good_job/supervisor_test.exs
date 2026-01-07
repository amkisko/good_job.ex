defmodule GoodJob.SupervisorTest do
  use ExUnit.Case, async: true

  test "shutdown? returns true when processes are not running" do
    assert GoodJob.Supervisor.shutdown?() == true
  end

  test "shutdown returns :ok when nothing is running" do
    assert GoodJob.Supervisor.shutdown(timeout: 0) == :ok
  end

  test "init builds child spec list" do
    assert {:ok, {_strategy, _children}} = GoodJob.Supervisor.init([])
  end
end
