defmodule GoodJob.Web.LiveDashboardPage.Handlers do
  @moduledoc """
  Event handlers for LiveDashboard page.
  """

  import Phoenix.Component
  alias GoodJob.{Job, PubSub, Web.DataLoader}

  @doc """
  Handles filter event.
  """
  def handle_filter(params, socket) do
    state = params["state"] || ""
    queue = params["queue"] || ""
    job_class = params["job_class"] || ""
    search = params["search"] || ""

    socket
    |> assign(
      filter_state: if(state == "", do: nil, else: state),
      filter_queue: if(queue == "", do: nil, else: queue),
      filter_job_class: if(job_class == "", do: nil, else: job_class),
      search_term: if(search == "", do: nil, else: search),
      current_page: 1
    )
    |> load_data_for_view(:jobs, nil, %{})
  end

  @doc """
  Handles toggle polling event.
  """
  def handle_toggle_polling(socket) do
    socket = assign(socket, polling: !socket.assigns.polling)

    if socket.assigns.polling do
      schedule_refresh(socket)
    end

    socket
  end

  @doc """
  Handles set poll interval event.
  """
  def handle_set_poll_interval(interval_str, socket) do
    interval = String.to_integer(interval_str) * 1000
    socket = assign(socket, poll_interval: interval)

    if socket.assigns.polling do
      schedule_refresh(socket)
    end

    socket
  end

  @doc """
  Handles retry job event.
  """
  def handle_retry_job(job_id, socket) do
    case Job.find_by_id(job_id) do
      nil ->
        socket

      job ->
        case Job.retry(job) do
          {:ok, _retried_job} ->
            socket
            |> load_data_for_view(socket.assigns.view, nil, %{})
            |> assign(nav_counts: DataLoader.load_nav_counts())

          {:error, _reason} ->
            socket
        end
    end
  end

  @doc """
  Handles delete job event.
  """
  def handle_delete_job(job_id, socket) do
    case Job.find_by_id(job_id) do
      nil ->
        socket

      job ->
        case Job.delete(job) do
          {:ok, _deleted_job} ->
            socket
            |> load_data_for_view(socket.assigns.view, nil, %{})
            |> assign(nav_counts: DataLoader.load_nav_counts())

          {:error, _reason} ->
            socket
        end
    end
  end

  @doc """
  Handles discard job event.
  """
  def handle_discard_job(job_id, socket) do
    case Job.find_by_id(job_id) do
      nil ->
        socket

      job ->
        repo = GoodJob.Repo.repo()
        now = DateTime.utc_now()

        case job
             |> Job.changeset(%{
               finished_at: now,
               error: "Manually discarded"
             })
             |> repo.update() do
          {:ok, _discarded_job} ->
            PubSub.broadcast(:job_discarded, job.id)

            socket
            |> load_data_for_view(socket.assigns.view, nil, %{})
            |> assign(nav_counts: DataLoader.load_nav_counts())

          {:error, _reason} ->
            socket
        end
    end
  end

  @doc """
  Handles bulk delete event.
  """
  def handle_bulk_delete(job_ids, socket) do
    job_ids
    |> Enum.each(fn job_id ->
      case Job.find_by_id(job_id) do
        nil -> :ok
        job -> Job.delete(job)
      end
    end)

    socket
    |> load_data_for_view(socket.assigns.view, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles bulk retry event.
  """
  def handle_bulk_retry(job_ids, socket) do
    job_ids
    |> Enum.each(fn job_id ->
      case Job.find_by_id(job_id) do
        nil -> :ok
        job -> Job.retry(job)
      end
    end)

    socket
    |> load_data_for_view(socket.assigns.view, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles toggle job selection event.
  """
  def handle_toggle_job_selection(job_id, socket) do
    selected = socket.assigns.selected_jobs

    selected =
      if MapSet.member?(selected, job_id) do
        MapSet.delete(selected, job_id)
      else
        MapSet.put(selected, job_id)
      end

    assign(socket, selected_jobs: selected)
  end

  @doc """
  Handles select all event.
  """
  def handle_select_all(socket) do
    job_ids = Enum.map(socket.assigns.jobs, & &1.id) |> Enum.map(&to_string/1)
    assign(socket, selected_jobs: MapSet.new(job_ids))
  end

  @doc """
  Handles deselect all event.
  """
  def handle_deselect_all(socket) do
    assign(socket, selected_jobs: MapSet.new())
  end

  @doc """
  Handles enable cron event.
  """
  def handle_enable_cron(cron_key, socket) do
    GoodJob.SettingManager.enable_cron(cron_key)

    socket
    |> load_data_for_view(:cron, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles disable cron event.
  """
  def handle_disable_cron(cron_key, socket) do
    GoodJob.SettingManager.disable_cron(cron_key)

    socket
    |> load_data_for_view(:cron, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles enqueue cron event.
  """
  def handle_enqueue_cron(cron_key, socket) do
    case DataLoader.get_cron_entry(cron_key) do
      nil ->
        socket

      entry ->
        now = DateTime.utc_now()
        cron_at = GoodJob.Cron.Entry.next_at(entry, now)
        GoodJob.Cron.Entry.enqueue(entry, cron_at)

        socket
        |> load_data_for_view(:cron, nil, %{})
        |> assign(nav_counts: DataLoader.load_nav_counts())
    end
  end

  @doc """
  Handles create pause event (by queue).
  """
  def handle_create_pause_queue(queue, socket) when queue != "" do
    GoodJob.SettingManager.pause(queue: queue)

    socket
    |> load_data_for_view(:pauses, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles create pause event (by job class).
  """
  def handle_create_pause_job_class(job_class, socket) when job_class != "" do
    GoodJob.SettingManager.pause(job_class: job_class)

    socket
    |> load_data_for_view(:pauses, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles delete pause event.
  """
  def handle_delete_pause(pause_key, socket) do
    GoodJob.SettingManager.unpause_by_key(pause_key)

    socket
    |> load_data_for_view(:pauses, nil, %{})
    |> assign(nav_counts: DataLoader.load_nav_counts())
  end

  @doc """
  Handles retry batch event.
  """
  def handle_retry_batch(batch_id, socket) do
    repo = GoodJob.Repo.repo()
    alias GoodJob.BatchRecord

    case repo.get(BatchRecord, batch_id) do
      nil ->
        socket

      batch ->
        GoodJob.Batch.retry_batch(batch)

        socket
        |> load_data_for_view(:batches, nil, %{})
        |> assign(nav_counts: DataLoader.load_nav_counts())
    end
  end

  # Private helpers

  defp load_data_for_view(socket, view, job_id, params) do
    GoodJob.Web.LiveDashboardPage.DataLoader.load_data_for_view(socket, view, job_id, params)
  end

  defp schedule_refresh(socket) do
    GoodJob.Web.LiveDashboardPage.Helpers.schedule_refresh(socket)
  end
end
