defmodule GoodJob.RegistryTest do
  use ExUnit.Case, async: false

  alias GoodJob.Registry, as: GoodJobRegistry

  test "start_link/1 starts a registry" do
    # Registry is already started in test_helper
    # Test that we can call start_link (it will return {:error, {:already_started, pid}})
    registry_pid = Process.whereis(GoodJobRegistry)

    case GoodJobRegistry.start_link([]) do
      {:ok, pid} ->
        assert Process.alive?(pid)

      {:error, {:already_started, pid}} ->
        # Registry already started, which is expected
        assert pid == registry_pid
        assert Process.alive?(pid)
    end

    # Verify it exists
    assert registry_pid != nil

    # Test that we can use the registry by registering a key
    # Use a unique key to avoid conflicts
    test_key = {:test, :registry_test, System.unique_integer([:positive])}
    test_value = self()

    # Use Elixir's Registry module directly (not GoodJob.Registry)
    # Registry.register/3 takes (registry_name, key, value)
    # It returns {:ok, pid} where pid is the process that registered
    result = Registry.register(GoodJobRegistry, test_key, test_value)
    assert match?({:ok, _pid}, result)

    # Registry.lookup returns list of {pid, value} tuples for the key
    lookup_result = Registry.lookup(GoodJobRegistry, test_key)
    assert lookup_result != []
    {found_pid, found_value} = List.first(lookup_result)
    assert found_value == test_value
    assert is_pid(found_pid)

    # Clean up
    Registry.unregister(GoodJobRegistry, test_key)
    assert Registry.lookup(GoodJobRegistry, test_key) == []
  end
end
