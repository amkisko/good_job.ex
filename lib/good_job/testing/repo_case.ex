defmodule GoodJob.Testing.RepoCase do
  @moduledoc """
  Test case template for tests that require a database.

  Provides Ecto Sandbox setup for database isolation in tests.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias GoodJob.{Repo, TestRepo}

      import Ecto
      import Ecto.Query
      import GoodJob.Testing.RepoCase
    end
  end

  setup tags do
    repo = GoodJob.Config.repo()

    owner_pid = start_owner_with_retry!(repo, shared: not tags[:async])
    ExUnit.Callbacks.on_exit(make_ref(), fn -> Sandbox.stop_owner(owner_pid) end)
    :ok
  end

  defp start_owner_with_retry!(repo, opts, retries \\ 3)

  defp start_owner_with_retry!(repo, opts, retries) when retries > 0 do
    Sandbox.start_owner!(repo, opts)
  rescue
    e in Postgrex.Error ->
      if admin_shutdown?(e) do
        Process.sleep(250)
        start_owner_with_retry!(repo, opts, retries - 1)
      else
        reraise e, __STACKTRACE__
      end

    e in DBConnection.ConnectionError ->
      if admin_shutdown?(e) do
        Process.sleep(250)
        start_owner_with_retry!(repo, opts, retries - 1)
      else
        reraise e, __STACKTRACE__
      end
  end

  defp start_owner_with_retry!(_repo, _opts, _retries) do
    raise "Failed to start SQL sandbox owner after retries (PostgreSQL admin shutdown)"
  end

  defp admin_shutdown?(%Postgrex.Error{postgres: %{code: :admin_shutdown}}), do: true
  defp admin_shutdown?(%Postgrex.Error{postgres: %{code: "57P01"}}), do: true

  defp admin_shutdown?(%DBConnection.ConnectionError{message: message}) when is_binary(message) do
    String.contains?(message, "admin_shutdown") or
      String.contains?(message, "terminating connection due to administrator command")
  end

  defp admin_shutdown?(_), do: false
end
