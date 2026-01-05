defmodule GoodJob.Repo do
  @moduledoc """
  Repository helper for GoodJob.

  Provides helper functions for database operations.
  """

  @doc """
  Returns the configured Ecto repository.
  """
  def repo do
    GoodJob.Config.repo()
  end

  @doc """
  Executes a query using the configured repository.
  """
  def query(sql, params \\ []) do
    repo().query!(sql, params)
  end

  @doc """
  Executes a query and returns the result.
  """
  def query_one(sql, params \\ []) do
    result = repo().query!(sql, params)

    case result.rows do
      [] -> nil
      [row | _] -> List.first(row)
    end
  rescue
    error -> {:error, error}
  end
end
