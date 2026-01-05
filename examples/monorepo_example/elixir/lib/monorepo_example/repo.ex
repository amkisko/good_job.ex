defmodule MonorepoExample.Repo do
  use Ecto.Repo,
    otp_app: :monorepo_example_worker,
    adapter: Ecto.Adapters.Postgres
end
