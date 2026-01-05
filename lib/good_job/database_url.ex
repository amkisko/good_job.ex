defmodule GoodJob.DatabaseURL do
  @moduledoc """
  Parses and configures database connection from DATABASE_URL environment variable.

  Similar to Rails database.yml, this module supports:
  - `DATABASE_URL` - Standard database URL (used if available)
  - `GOOD_JOB_DATABASE_URL` - GoodJob-specific database URL (takes precedence)

  ## Database URL Format

  PostgreSQL:
  ```
  postgres://username:password@hostname:port/database
  postgresql://username:password@hostname:port/database
  ```

  Examples:
  ```
  postgres://user:pass@localhost:5432/myapp_production
  postgresql://postgres:postgres@db.example.com:5432/good_job
  ```

  ## Usage

  In your config files:

      # config/runtime.exs
      import Config

      # Parse DATABASE_URL and configure repo
      if database_url = System.get_env("GOOD_JOB_DATABASE_URL") || System.get_env("DATABASE_URL") do
        GoodJob.DatabaseURL.configure_repo(MyApp.Repo, database_url)
      end

  Or use the helper to get parsed config:

      config = GoodJob.DatabaseURL.parse("postgres://user:pass@localhost/mydb")
      # => %{username: "user", password: "pass", hostname: "localhost", ...}

      config :my_app, MyApp.Repo, config
  """

  @doc """
  Parses a database URL and returns connection parameters.

  Returns a keyword list suitable for Ecto repository configuration.

  ## Examples

      GoodJob.DatabaseURL.parse("postgres://user:pass@localhost:5432/mydb")
      # => [
      #   username: "user",
      #   password: "pass",
      #   hostname: "localhost",
      #   port: 5432,
      #   database: "mydb",
      #   adapter: Ecto.Adapters.Postgres
      # ]
  """
  @spec parse(String.t()) :: keyword()
  def parse(url) when is_binary(url) do
    uri = URI.parse(url)

    # Extract database name from path
    database =
      case uri.path do
        "/" <> db -> db
        path when is_binary(path) -> String.trim_leading(path, "/")
        _ -> nil
      end

    # Extract username and password
    {username, password} = parse_userinfo(uri.userinfo)

    # Determine adapter from scheme
    adapter = parse_adapter(uri.scheme)

    # Build config keyword list
    config = [
      username: username,
      password: password,
      hostname: uri.host || "localhost",
      port: uri.port || default_port(adapter),
      database: database,
      adapter: adapter
    ]

    # Add query parameters as additional options
    query_params = parse_query(uri.query)
    Keyword.merge(config, query_params)
  end

  @doc """
  Configures a repository from a database URL.

  This function parses the URL and applies the configuration to the given repo.

  ## Examples

      GoodJob.DatabaseURL.configure_repo(MyApp.Repo, "postgres://user:pass@localhost/mydb")

  This is equivalent to:

      config :my_app, MyApp.Repo,
        username: "user",
        password: "pass",
        hostname: "localhost",
        port: 5432,
        database: "mydb"
  """
  @spec configure_repo(module(), String.t()) :: :ok
  def configure_repo(repo_module, url) when is_atom(repo_module) and is_binary(url) do
    config = parse(url)
    app = repo_module |> Module.split() |> List.first() |> String.downcase() |> String.to_atom()

    Application.put_env(app, repo_module, config)
    :ok
  end

  @doc """
  Gets the database URL from environment variables.

  Checks in order:
  1. `GOOD_JOB_DATABASE_URL` (GoodJob-specific, takes precedence)
  2. `DATABASE_URL` (standard, fallback)

  Returns `nil` if neither is set.

  ## Examples

      GoodJob.DatabaseURL.from_env()
      # => "postgres://user:pass@localhost/mydb" or nil
  """
  @spec from_env() :: String.t() | nil
  def from_env do
    System.get_env("GOOD_JOB_DATABASE_URL") || System.get_env("DATABASE_URL")
  end

  @doc """
  Configures a repository from environment variables.

  This is a convenience function that combines `from_env/0` and `configure_repo/2`.

  ## Examples

      # In config/runtime.exs
      GoodJob.DatabaseURL.configure_repo_from_env(MyApp.Repo)

  This will:
  1. Check for `GOOD_JOB_DATABASE_URL` or `DATABASE_URL`
  2. Parse the URL
  3. Configure the repository

  If no URL is found, this function does nothing (does not raise an error).
  """
  @spec configure_repo_from_env(module()) :: :ok | :no_url
  def configure_repo_from_env(repo_module) when is_atom(repo_module) do
    case from_env() do
      nil -> :no_url
      url -> configure_repo(repo_module, url)
    end
  end

  # Private functions

  defp parse_userinfo(nil), do: {nil, nil}

  defp parse_userinfo(userinfo) when is_binary(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [user, pass] -> {user, pass}
      [user] -> {user, nil}
      _ -> {nil, nil}
    end
  end

  defp parse_adapter("postgres"), do: Ecto.Adapters.Postgres
  defp parse_adapter("postgresql"), do: Ecto.Adapters.Postgres
  defp parse_adapter(_scheme), do: Ecto.Adapters.Postgres

  defp default_port(Ecto.Adapters.Postgres), do: 5432
  # All adapters default to 5432 for now
  defp default_port(_adapter), do: 5432

  defp parse_query(nil), do: []
  defp parse_query(""), do: []

  defp parse_query(query_string) when is_binary(query_string) do
    query_string
    |> URI.decode_query()
    |> Enum.map(fn {key, value} ->
      # Convert string keys to atoms where appropriate
      atom_key = normalize_query_key(key)
      {atom_key, normalize_query_value(value)}
    end)
    |> Keyword.new()
  end

  defp normalize_query_key(key) when is_binary(key) do
    # Convert common query parameters to atoms
    case key do
      "pool_size" -> :pool_size
      "pool_timeout" -> :pool_timeout
      "timeout" -> :timeout
      "ssl" -> :ssl
      "ssl_opts" -> :ssl_opts
      "parameters" -> :parameters
      _ -> String.to_atom(key)
    end
  end

  defp normalize_query_value(value) when is_binary(value) do
    # Try to parse as integer
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> value
    end
  end

  defp normalize_query_value(value), do: value
end
