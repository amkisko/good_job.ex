defmodule GoodJob.Config.DefaultsTest do
  use ExUnit.Case, async: true

  alias GoodJob.Config.Defaults

  test "defaults returns a map with expected keys" do
    defaults = Defaults.defaults()
    assert is_map(defaults)
    assert defaults[:execution_mode] == :external
    assert defaults[:queues] == "*"
  end

  test "get returns default values and nil for missing keys" do
    assert Defaults.get(:poll_interval) == 10
    assert Defaults.get(:missing_key) == nil
  end

  test "merge overrides defaults and preserves unspecified values" do
    merged = Defaults.merge(%{poll_interval: 5, new_key: :value})
    assert merged[:poll_interval] == 5
    assert merged[:new_key] == :value
    assert merged[:execution_mode] == :external
  end
end
