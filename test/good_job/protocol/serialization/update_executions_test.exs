defmodule GoodJob.Protocol.Serialization.UpdateExecutionsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Protocol.Serialization

  describe "update_executions/2" do
    test "updates executions count" do
      params = %{"executions" => 0}
      updated = Serialization.update_executions(params, 1)
      assert updated["executions"] == 1
    end

    test "adds executions field if missing" do
      params = %{}
      updated = Serialization.update_executions(params, 1)
      assert updated["executions"] == 1
    end
  end
end
