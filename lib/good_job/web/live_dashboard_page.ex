defmodule GoodJob.Web.LiveDashboardPage do
  @moduledoc """
  Phoenix LiveDashboard page for GoodJob.

  This module provides a comprehensive dashboard with the following features:
  - Real-time job queue statistics via PubSub (with polling fallback)
  - Job filtering and search
  - Job detail view with execution history
  - Job actions (retry, delete, discard)
  - Bulk actions
  - Pagination
  - Configurable fallback polling (PubSub handles real-time updates)
  """

  use Phoenix.LiveView

  import Phoenix.Component

  alias GoodJob.{PubSub, Web.Components}
  alias GoodJob.Web.LiveDashboardPage.{DataLoader, Handlers, Helpers}

  @default_per_page 25
  # Increased to 30s since PubSub handles real-time updates

  @doc """
  Returns the path to the bundled ECharts JavaScript file.
  Falls back to CDN if static file is not available.

  For standalone use, configure Plug.Static in your endpoint to serve files from :good_job:

      plug Plug.Static,
        at: "/good_job/static",
        from: {:good_job, "priv/static"},
        gzip: true
  """
  def echarts_js_path do
    # Try to use bundled version from priv/static
    path = Application.app_dir(:good_job, "priv/static/js/echarts.min.js")

    if File.exists?(path) do
      # Return a path that can be served via Plug.Static
      # Users need to configure Plug.Static to serve from :good_job's priv/static
      "/good_job/static/js/echarts.min.js"
    else
      # Fallback to CDN
      "https://cdn.jsdelivr.net/npm/echarts@5.4.3/dist/echarts.min.js"
    end
  end

  @doc """
  Returns the LiveView module for this page.
  This is required by Phoenix LiveDashboard for additional pages.
  """
  def __page_live__(_opts) do
    __MODULE__
  end

  @doc """
  Initializes the LiveDashboard page configuration.
  """
  def init(_opts) do
    {:ok, %{title: "GoodJob"}}
  end

  @doc """
  Returns the menu link text for the LiveDashboard navigation.
  """
  def menu_link(_session, _capabilities) do
    {:ok, "GoodJob"}
  end

  @impl true
  def mount(params, _session, socket) do
    # LiveDashboard passes page name as params["page"], extract our params
    params = if is_map(params), do: params, else: %{}
    our_params = Map.delete(params, "page")
    poll_interval = Helpers.parse_poll_interval(our_params)

    # CRITICAL: Initialize params as a map using assign/3 (not Component.assign)
    socket = assign(socket, params: params)

    # Now assign all our other assigns (using current_page instead of page to avoid conflicts)
    socket =
      socket
      |> assign(
        view: :overview,
        stats: GoodJob.Web.DataLoader.load_stats(),
        chart_data: GoodJob.Web.DataLoader.load_chart_data(),
        jobs: [],
        job: nil,
        executions: [],
        current_page: 1,
        per_page: @default_per_page,
        total_count: 0,
        filter_state: nil,
        filter_queue: nil,
        filter_job_class: nil,
        search_term: nil,
        date_from: nil,
        date_to: nil,
        selected_jobs: MapSet.new(),
        poll_interval: poll_interval,
        polling: true,
        nav_counts: GoodJob.Web.DataLoader.load_nav_counts()
      )

    socket =
      if connected?(socket) do
        case PubSub.subscribe() do
          topic when is_binary(topic) ->
            Helpers.schedule_refresh(socket)
            assign(socket, :pubsub_enabled, true)

          nil ->
            Helpers.schedule_refresh(socket)
            assign(socket, :pubsub_enabled, false)
        end
      else
        assign(socket, :pubsub_enabled, false)
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # LiveDashboard passes page name as params["page"] (e.g., "good_job")
    # Ensure params is a map
    params = if is_map(params), do: params, else: %{}

    # CRITICAL: Ensure socket.assigns.params is ALWAYS a map
    # LiveDashboard's PageLive wrapper will try to update it and expects a map
    # Defensively check and fix if needed
    current_params = Map.get(socket.assigns, :params)

    socket =
      if is_map(current_params) do
        socket
      else
        # Force params to be a map - this should never happen but we're being defensive
        Phoenix.Component.assign(socket, :params, %{})
      end

    # Extract our query parameters (ignore LiveDashboard's "page" key)
    view = Helpers.parse_view(params)
    job_id = params["job_id"]
    page_num = Helpers.parse_page(params)

    # Update our own assigns (don't touch params - LiveDashboard manages it)
    socket =
      socket
      |> assign(
        view: view,
        current_page: page_num,
        filter_state: params["state"],
        filter_queue: params["queue"],
        filter_job_class: params["job_class"],
        search_term: params["search"]
      )
      |> DataLoader.load_data_for_view(view, job_id, params)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    # Polling fallback - only continue if polling is enabled
    # Real-time updates come via PubSub, so polling is just a safety net
    if socket.assigns.polling do
      Helpers.schedule_refresh(socket)
    end

    socket =
      socket
      |> DataLoader.load_data_for_view(socket.assigns.view, nil, %{})
      |> assign(nav_counts: GoodJob.Web.DataLoader.load_nav_counts())

    {:noreply, socket}
  end

  @impl true
  def handle_info({event, _job_id}, socket)
      when event in [:job_created, :job_updated, :job_completed, :job_deleted, :job_retried, :job_discarded] do
    socket =
      socket
      |> DataLoader.load_data_for_view(socket.assigns.view, nil, %{})
      |> assign(nav_counts: GoodJob.Web.DataLoader.load_nav_counts())

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    socket = Handlers.handle_filter(params, socket)
    {:noreply, socket}
  end

  def handle_event("toggle_polling", _params, socket) do
    socket = Handlers.handle_toggle_polling(socket)
    {:noreply, socket}
  end

  def handle_event("set_poll_interval", %{"interval" => interval_str}, socket) do
    socket = Handlers.handle_set_poll_interval(interval_str, socket)
    {:noreply, socket}
  end

  def handle_event("retry_job", %{"job_id" => job_id}, socket) do
    socket = Handlers.handle_retry_job(job_id, socket)
    {:noreply, socket}
  end

  def handle_event("delete_job", %{"job_id" => job_id}, socket) do
    socket = Handlers.handle_delete_job(job_id, socket)
    {:noreply, socket}
  end

  def handle_event("discard_job", %{"job_id" => job_id}, socket) do
    socket = Handlers.handle_discard_job(job_id, socket)
    {:noreply, socket}
  end

  def handle_event("bulk_delete", %{"job_ids" => job_ids}, socket) do
    job_ids = String.split(job_ids, ",")
    socket = Handlers.handle_bulk_delete(job_ids, socket)
    {:noreply, assign(socket, selected_jobs: MapSet.new())}
  end

  def handle_event("bulk_retry", %{"job_ids" => job_ids}, socket) do
    job_ids = String.split(job_ids, ",")
    socket = Handlers.handle_bulk_retry(job_ids, socket)
    {:noreply, assign(socket, selected_jobs: MapSet.new())}
  end

  def handle_event("toggle_job_selection", %{"job_id" => job_id}, socket) do
    socket = Handlers.handle_toggle_job_selection(job_id, socket)
    {:noreply, socket}
  end

  def handle_event("select_all", _params, socket) do
    socket = Handlers.handle_select_all(socket)
    {:noreply, socket}
  end

  def handle_event("deselect_all", _params, socket) do
    socket = Handlers.handle_deselect_all(socket)
    {:noreply, socket}
  end

  def handle_event("navigate", %{"view" => view}, socket) do
    uri = Helpers.build_uri(view, nil, socket.assigns)
    {:noreply, push_patch(socket, to: uri)}
  end

  def handle_event("view_job", %{"job_id" => job_id}, socket) do
    uri = Helpers.build_uri("job_detail", job_id, socket.assigns)
    {:noreply, push_patch(socket, to: uri)}
  end

  def handle_event("navigate", %{"page" => page_str}, socket) do
    page =
      case Integer.parse(page_str) do
        {page, _} -> max(1, page)
        _ -> 1
      end

    # Preserve the current view when navigating to a different page
    current_view = socket.assigns.view || :jobs
    view_name = if is_atom(current_view), do: Atom.to_string(current_view), else: current_view

    uri = Helpers.build_uri(view_name, nil, Map.put(socket.assigns, :current_page, page))
    {:noreply, push_patch(socket, to: uri)}
  end

  # Cron event handlers
  def handle_event("enable_cron", %{"cron_key" => cron_key}, socket) do
    socket = Handlers.handle_enable_cron(cron_key, socket)
    {:noreply, socket}
  end

  def handle_event("disable_cron", %{"cron_key" => cron_key}, socket) do
    socket = Handlers.handle_disable_cron(cron_key, socket)
    {:noreply, socket}
  end

  def handle_event("enqueue_cron", %{"cron_key" => cron_key}, socket) do
    socket = Handlers.handle_enqueue_cron(cron_key, socket)
    {:noreply, socket}
  end

  # Pause event handlers
  def handle_event("create_pause", %{"queue" => queue}, socket) when queue != "" do
    socket = Handlers.handle_create_pause_queue(queue, socket)
    {:noreply, socket}
  end

  def handle_event("create_pause", %{"job_class" => job_class}, socket) when job_class != "" do
    socket = Handlers.handle_create_pause_job_class(job_class, socket)
    {:noreply, socket}
  end

  def handle_event("create_pause", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("delete_pause", %{"pause_key" => pause_key}, socket) do
    socket = Handlers.handle_delete_pause(pause_key, socket)
    {:noreply, socket}
  end

  # Batch event handlers
  def handle_event("retry_batch", %{"batch_id" => batch_id}, socket) do
    socket = Handlers.handle_retry_batch(batch_id, socket)
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="good-job-dashboard">
      <Components.Navigation.breadcrumbs {assigns} />
      <Components.Navigation.navbar {assigns} />
      <div class="row mb-3">
        <div class="col-12">
          <div class="d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">GoodJob Dashboard</h5>
            <div class="d-flex align-items-center gap-2">
              <%= if @pubsub_enabled do %>
                <span class="badge bg-success small">Real-time (PubSub)</span>
              <% else %>
                <span class="badge bg-warning small">Polling Only</span>
              <% end %>
              <label class="form-check-label small">
                <input
                  type="checkbox"
                  class="form-check-input"
                  checked={@polling}
                  phx-click="toggle_polling"
                />
                Fallback Poll
              </label>
              <select
                class="form-select form-select-sm"
                style="width: auto;"
                phx-change="set_poll_interval"
                value={div(@poll_interval, 1000)}
              >
                <option value="10">10s</option>
                <option value="30">30s</option>
                <option value="60">60s</option>
                <option value="120">2m</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <%= cond do %>
        <% @view == :overview -> %>
          <Components.Overview.render {assigns} />
        <% @view == :jobs -> %>
          <Components.Jobs.render {assigns} />
        <% @view == :job_detail -> %>
          <Components.JobDetail.render {assigns} />
        <% @view == :cron -> %>
          <Components.Cron.render {assigns} />
        <% @view == :pauses -> %>
          <Components.Pauses.render {assigns} />
        <% @view == :batches -> %>
          <Components.Batches.render {assigns} />
        <% @view == :processes -> %>
          <Components.Processes.render {assigns} />
      <% end %>
    </div>
    """
  end
end
