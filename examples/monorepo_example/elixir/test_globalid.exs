# Test script for GlobalID resolution in Elixir
# Run with: mix run test_globalid.exs

alias GoodJob.Protocol.Serialization

IO.puts("Testing GlobalID Resolution in Elixir")
IO.puts(String.duplicate("=", 50))

# Test 1: Deserialize a GlobalID from ActiveJob format
IO.puts("\nTest 1: Deserializing GlobalID from ActiveJob format")
IO.puts(String.duplicate("-", 50))

globalid_arg = %{"_aj_globalid" => "gid://myapp/User/123"}

{:ok, _job_class, deserialized_args, _executions, _metadata} =
  Serialization.from_active_job(%{
    "job_class" => "GlobalidTestJob",
    "arguments" => [globalid_arg],
    "queue_name" => "ex.default",
    "executions" => 0
  })

user = List.first(deserialized_args)

case user do
  %{__struct__: :global_id, app: app, model: model, id: id, gid: gid} ->
    IO.puts("✓ GlobalID deserialized successfully")
    IO.puts("  App: #{app}")
    IO.puts("  Model: #{model}")
    IO.puts("  ID: #{id}")
    IO.puts("  GID: #{gid}")

  other ->
    IO.puts("✗ GlobalID deserialization failed")
    IO.puts("  Got: #{inspect(other)}")
end

# Test 2: Deserialize GlobalID nested in a map
IO.puts("\nTest 2: Deserializing GlobalID nested in a map")
IO.puts(String.duplicate("-", 50))

nested_globalid = %{
  "user" => %{"_aj_globalid" => "gid://myapp/User/456"},
  "action" => "process"
}

{:ok, _job_class, deserialized_nested, _executions, _metadata} =
  Serialization.from_active_job(%{
    "job_class" => "GlobalidTestJob",
    "arguments" => [nested_globalid],
    "queue_name" => "ex.default",
    "executions" => 0
  })

nested_user = List.first(deserialized_nested) |> Map.get("user")

case nested_user do
  %{__struct__: :global_id, app: app, model: model, id: id, gid: gid} ->
    IO.puts("✓ Nested GlobalID deserialized successfully")
    IO.puts("  App: #{app}")
    IO.puts("  Model: #{model}")
    IO.puts("  ID: #{id}")
    IO.puts("  GID: #{gid}")

  other ->
    IO.puts("✗ Nested GlobalID deserialization failed")
    IO.puts("  Got: #{inspect(other)}")
end

# Test 3: Test invalid GlobalID format
IO.puts("\nTest 3: Testing invalid GlobalID format")
IO.puts(String.duplicate("-", 50))

invalid_globalid = %{"_aj_globalid" => "invalid-format"}

{:ok, _job_class, deserialized_invalid, _executions, _metadata} =
  Serialization.from_active_job(%{
    "job_class" => "GlobalidTestJob",
    "arguments" => [invalid_globalid],
    "queue_name" => "ex.default",
    "executions" => 0
  })

invalid_user = List.first(deserialized_invalid)

case invalid_user do
  "invalid-format" ->
    IO.puts("✓ Invalid GlobalID handled gracefully (returned as string)")

  other ->
    IO.puts("✗ Invalid GlobalID not handled correctly")
    IO.puts("  Got: #{inspect(other)}")
end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Test complete!")
