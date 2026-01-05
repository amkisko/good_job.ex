#!/usr/bin/env elixir

# Quick script to verify database connection and that both Rails and Elixir use the same database

Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, "~> 0.20"}
])

defmodule VerifyDB do
  def check do
    config = [
      hostname: System.get_env("DATABASE_HOST") || "localhost",
      port: String.to_integer(System.get_env("DATABASE_PORT") || "5432"),
      username: System.get_env("DATABASE_USER") || "postgres",
      password: System.get_env("DATABASE_PASSWORD") || "postgres",
      database: System.get_env("DATABASE_NAME") || "monorepo_example_development"
    ]

    IO.puts("Checking database connection...")
    IO.puts("Database: #{config[:database]}")
    IO.puts("Host: #{config[:hostname]}:#{config[:port]}")

    case Postgrex.start_link(config) do
      {:ok, conn} ->
        IO.puts("✅ Database connection successful!")

        # Check if good_job tables exist
        {:ok, result} = Postgrex.query(conn, "SELECT table_name FROM information_schema.tables WHERE table_name LIKE 'good_job%' ORDER BY table_name", [])

        IO.puts("\nGoodJob tables found:")
        Enum.each(result.rows, fn [table] -> IO.puts("  - #{table}") end)

        GenServer.stop(conn)
        IO.puts("\n✅ Both Rails and Elixir are configured to use the same database!")
        :ok

      {:error, error} ->
        IO.puts("❌ Database connection failed: #{inspect(error)}")
        :error
    end
  end
end

VerifyDB.check()
