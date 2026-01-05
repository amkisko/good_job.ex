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

      # The :ok return value is required by Ecto.Adapters.SQL.Sandbox
      setup do
        repo = GoodJob.Config.repo()

        # Handle case where checkout might already be done (for shared tests)
        try do
          :ok = Sandbox.checkout(repo)
        rescue
          e in MatchError ->
            case e.term do
              {:already, :owner} -> :ok
              {:error, {:already, :owner}} -> :ok
              _ -> reraise e, __STACKTRACE__
            end
        end
      end
    end
  end

  setup tags do
    repo = GoodJob.Config.repo()

    # Handle case where sandbox is already shared (for async: false tests)
    try do
      pid = Sandbox.start_owner!(repo, shared: not tags[:async])
      # on_exit is available in setup blocks via ExUnit.CaseTemplate
      ExUnit.Callbacks.on_exit(fn -> Sandbox.stop_owner(pid) end)
      :ok
    rescue
      # Sandbox is already shared or owner already exists, which is fine for async: false tests
      e in MatchError ->
        case e.term do
          {:error, {{:badmatch, :already_shared}, _}} -> :ok
          {{:badmatch, :already_shared}, _} -> :ok
          {:already, :owner} -> :ok
          {:error, {:already, :owner}} -> :ok
          _ -> reraise e, __STACKTRACE__
        end

      # Other errors - re-raise
      e ->
        reraise e, __STACKTRACE__
    end
  end
end
