defmodule GoodJob.TestRepo do
  @moduledoc """
  Test repository for GoodJob tests.

  This is a minimal Ecto repository used only for testing the GoodJob library itself.
  Applications using GoodJob should use their own repository.
  """

  use Ecto.Repo,
    otp_app: :good_job,
    adapter: Ecto.Adapters.Postgres
end
