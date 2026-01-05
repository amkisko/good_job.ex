defmodule HabitTracker.Repo do
  use Ecto.Repo,
    otp_app: :habit_tracker,
    adapter: Ecto.Adapters.Postgres
end
