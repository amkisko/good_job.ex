defmodule HabitTracker.Jobs.PointsCalculationJob do
  @moduledoc """
  Job that calculates total points, daily points, weekly points, and monthly points.
  Runs daily via cron to update point records.
  """
  use GoodJob.Job,
    queue: "default",
    priority: 10,
    max_attempts: 3,
    timeout: 60_000

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Completion, PointRecord}
  import Ecto.Query

  @impl true
  def perform(_args) do
    today = Date.utc_today()
    week_start = Date.beginning_of_week(today, :monday)
    month_start = Date.new!(today.year, today.month, 1)

    # Calculate total points (all time)
    total_points =
      Repo.one(from c in Completion, select: sum(c.points_earned)) || 0

    # Calculate points today
    points_today =
      Repo.one(
        from c in Completion,
          where: fragment("DATE(?)", c.completed_at) == ^today,
          select: sum(c.points_earned)
      ) || 0

    # Calculate points this week
    points_this_week =
      Repo.one(
        from c in Completion,
          where: fragment("DATE(?)", c.completed_at) >= ^week_start,
          select: sum(c.points_earned)
      ) || 0

    # Calculate points this month
    points_this_month =
      Repo.one(
        from c in Completion,
          where: fragment("DATE(?)", c.completed_at) >= ^month_start,
          select: sum(c.points_earned)
      ) || 0

    # Update or create point record
    point_record =
      case Repo.one(from p in PointRecord, limit: 1, order_by: [desc: p.inserted_at]) do
        nil ->
          %PointRecord{}
          |> PointRecord.changeset(%{
            total_points: total_points,
            points_today: points_today,
            points_this_week: points_this_week,
            points_this_month: points_this_month,
            calculated_at: DateTime.utc_now()
          })
          |> Repo.insert!()

        record ->
          record
          |> PointRecord.changeset(%{
            total_points: total_points,
            points_today: points_today,
            points_this_week: points_this_week,
            points_this_month: points_this_month,
            calculated_at: DateTime.utc_now()
          })
          |> Repo.update!()
      end

    {:ok,
     %{
       total_points: point_record.total_points,
       points_today: point_record.points_today,
       points_this_week: point_record.points_this_week,
       points_this_month: point_record.points_this_month
     }}
  end
end
