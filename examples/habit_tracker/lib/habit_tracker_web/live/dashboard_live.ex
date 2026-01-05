defmodule HabitTrackerWeb.DashboardLive do
  @moduledoc """
  LiveView for the main dashboard showing today's tasks and stats.
  """
  use HabitTrackerWeb, :live_view

  alias HabitTracker.Repo
  alias HabitTracker.Schemas.{Habit, Task, PointRecord}
  alias GoodJob.Job
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:debounce_ref, nil)
      |> assign(:job_tracking, %{})

    if connected?(socket) do
      # Subscribe to PubSub for real-time job updates
      Phoenix.PubSub.subscribe(HabitTracker.PubSub, "good_job:jobs")
      # Don't start polling immediately - wait for PubSub events or user actions
      # Polling will start automatically when jobs are tracked
    end

    {:ok, load_data(socket)}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Only continue polling if there are active jobs being tracked
    schedule_refresh_if_needed(socket)
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_info({event, _job_id}, socket)
      when event in [:job_created, :job_updated, :job_completed, :job_deleted, :job_retried] do
    # Real-time update from PubSub - debounce to avoid multiple rapid refreshes
    # Cancel any pending debounced refresh and schedule a new one
    debounce_ref = make_ref()
    Process.send_after(self(), {:debounced_refresh, debounce_ref, event}, 500)
    {:noreply, assign(socket, :debounce_ref, debounce_ref)}
  end

  @impl true
  def handle_info({:debounced_refresh, debounce_ref, _event}, socket) do
    # Only process if this is still the current debounce ref (not cancelled)
    if socket.assigns[:debounce_ref] == debounce_ref do
      # Debounced refresh after PubSub event
      # Only continue polling if there are active jobs
      schedule_refresh_if_needed(socket)
      {:noreply, load_data(socket)}
    else
      # This debounce was cancelled, ignore it
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("complete_task", params, socket) do
    # Handle both "task_id" and "task-id" (Phoenix may convert underscores to hyphens)
    task_id = Map.get(params, "task_id") || Map.get(params, "task-id")

    unless task_id do
      {:noreply, put_flash(socket, :error, "Missing task_id parameter")}
    else
      # Enqueue job to complete the task
      case HabitTracker.Jobs.TaskCompletionJob.perform_later(%{task_id: task_id}) do
        {:ok, job} ->
          # Store job ID for tracking
          job_tracking = Map.put(socket.assigns[:job_tracking] || %{}, task_id, job.active_job_id)

        {:noreply,
         socket
         |> assign(job_tracking: job_tracking)
         |> put_flash(:info, "🐱 Helper cat is working on it! 🌸 Your stars will appear soon!")
         |> load_data()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "😿 Oops! Something went wrong. Let's try again! 🌸")}
      end
    end
  end

  defp load_data(socket) do
    today = Date.utc_today()

    # Optimized query: get all enabled habits with today's tasks and streaks
    # Use proper preloading to avoid N+1 queries
    habits =
      from h in Habit,
        where: h.enabled == true,
        order_by: [asc: h.category, asc: h.name]

    habits = Repo.all(habits)

    # Ensure tasks exist for today (defensive check - in case cron job hasn't run yet)
    # This ensures the dashboard always works even if the cron job failed or hasn't run
    ensure_tasks_for_today(habits, today)

    # Preload tasks and streaks efficiently in batch
    habits =
      habits
      |> Repo.preload(tasks: from(t in Task, where: t.date == ^today))
      |> Repo.preload(:streaks)

    # Get point record
    point_record =
      (Repo.one(from p in PointRecord, limit: 1, order_by: [desc: p.inserted_at])) ||
        %PointRecord{total_points: 0, points_today: 0, points_this_week: 0, points_this_month: 0}

    # Prepare data for rendering
    # Clean up job_tracking: remove completed jobs
    job_tracking = socket.assigns[:job_tracking] || %{}

    # Filter out completed jobs from tracking
    # Batch query all jobs at once instead of individual queries
    active_job_ids = Map.values(job_tracking) |> Enum.uniq()

    cleaned_job_tracking =
      if Enum.empty?(active_job_ids) do
        %{}
      else
        # Batch query all jobs at once
        jobs_map =
          Job
          |> where([j], j.active_job_id in ^active_job_ids)
          |> GoodJob.Repo.repo().all()
          |> Enum.map(fn job -> {job.active_job_id, Job.calculate_state(job)} end)
          |> Map.new()

        Enum.reduce(job_tracking, %{}, fn {task_id, active_job_id}, acc ->
          case Map.get(jobs_map, active_job_id) do
            nil -> acc  # Job not found, remove from tracking
            :succeeded -> acc  # Remove completed jobs
            :discarded -> acc  # Remove failed jobs
            _ -> Map.put(acc, task_id, active_job_id)  # Keep tracking for in-progress jobs
          end
        end)
      end

    habits_data =
      Enum.map(habits, fn habit ->
        task = List.first(habit.tasks)
        streak = List.first(habit.streaks)

        # Only show job_id if task can still be completed more times
        # Check completion_count vs max_completions instead of just completed boolean
        max_completions = habit.max_completions || 1
        completion_count = if task, do: (task.completion_count || 0), else: 0
        _can_complete_more = completion_count < max_completions

        job_id = if task && completion_count < max_completions do
          Map.get(cleaned_job_tracking, to_string(task.id))
        else
          nil
        end

        %{
          habit: habit,
          task: task,
          streak: streak,
          job_id: job_id
        }
      end)

    # Final cleanup: remove any job tracking for tasks that can't be completed more
    final_job_tracking =
      Enum.reduce(habits_data, cleaned_job_tracking, fn %{task: task, habit: habit}, acc ->
        if task do
          max_completions = habit.max_completions || 1
          completion_count = task.completion_count || 0
          can_complete_more = completion_count < max_completions

          if !can_complete_more do
            # Task has reached completion limit, remove from tracking
            Map.delete(acc, to_string(task.id))
          else
            acc
          end
        else
          acc
        end
      end)

    assign(socket,
      habits: habits_data,
      point_record: point_record,
      today: today,
      job_tracking: final_job_tracking
    )
  end

  # Ensure tasks exist for today for all enabled habits
  # This is a defensive check in case the cron job hasn't run yet or failed
  defp ensure_tasks_for_today(habits, today) do
    if Enum.empty?(habits) do
      :ok
    else
      habit_ids = Enum.map(habits, & &1.id)

      # Batch query to find existing tasks
      existing_tasks =
        from(t in Task,
          where: t.habit_id in ^habit_ids and t.date == ^today,
          select: t.habit_id
        )
        |> Repo.all()
        |> MapSet.new()

      # Create missing tasks in batch
      missing_habits = Enum.reject(habits, fn habit -> habit.id in existing_tasks end)

      if Enum.any?(missing_habits) do
        # Insert all missing tasks in a single transaction
        Repo.transaction(fn ->
          for habit <- missing_habits do
            %Task{}
            |> Task.changeset(%{
              habit_id: habit.id,
              date: today,
              completed: false,
              points_earned: 0,
              completion_count: 0
            })
            |> Repo.insert!()
          end
        end)
      end
    end
  end

  # Track the refresh timer reference to allow cancellation
  defp schedule_refresh_if_needed(socket) do
    # Only poll if there are active jobs being tracked
    # This significantly reduces database load when nothing is happening
    job_tracking = socket.assigns[:job_tracking] || %{}

    if map_size(job_tracking) > 0 do
      # There are active jobs, poll every 5 seconds to check their status
      Process.send_after(self(), :refresh, 5_000)
    else
      # No active jobs, poll less frequently (every 30 seconds) just to catch any new jobs
      Process.send_after(self(), :refresh, 30_000)
    end
  end


  @impl true
  def render(assigns) do
    Phlex.Phoenix.to_rendered(
      HabitTrackerWeb.Components.Dashboard.render(assigns)
    )
  end
end
