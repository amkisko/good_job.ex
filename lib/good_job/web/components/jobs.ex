defmodule GoodJob.Web.Components.Jobs do
  @moduledoc """
  Jobs list component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.{Job, Web.Formatters}

  def render(assigns) do
    ~H"""
    <div class="row mb-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Jobs</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="overview"
            >
              ← Overview
            </button>
          </div>
          <div class="card-body">
            <form phx-change="filter" phx-debounce="500" class="row g-3">
              <div class="col-md-2">
                <label class="form-label small">State</label>
                <select name="state" class="form-select form-select-sm" phx-debounce="blur">
                  <option value="">All</option>
                  <option value="queued" selected={@filter_state == "queued"}>Queued</option>
                  <option value="running" selected={@filter_state == "running"}>Running</option>
                  <option value="succeeded" selected={@filter_state == "succeeded"}>Succeeded</option>
                  <option value="discarded" selected={@filter_state == "discarded"}>Discarded</option>
                  <option value="scheduled" selected={@filter_state == "scheduled"}>Scheduled</option>
                </select>
              </div>
              <div class="col-md-2">
                <label class="form-label small">Queue</label>
                <input
                  type="text"
                  name="queue"
                  class="form-control form-control-sm"
                  placeholder="Queue name"
                  value={@filter_queue || ""}
                  phx-debounce="500"
                />
              </div>
              <div class="col-md-2">
                <label class="form-label small">Job Class</label>
                <input
                  type="text"
                  name="job_class"
                  class="form-control form-control-sm"
                  placeholder="Job class"
                  value={@filter_job_class || ""}
                  phx-debounce="500"
                />
              </div>
              <div class="col-md-4">
                <label class="form-label small">Search</label>
                <input
                  type="text"
                  name="search"
                  class="form-control form-control-sm"
                  placeholder="Search jobs..."
                  value={@search_term || ""}
                  phx-debounce="500"
                />
              </div>
              <div class="col-md-2 d-flex align-items-end">
                <button type="submit" class="btn btn-sm btn-primary w-100">Filter</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>

    <%= if MapSet.size(@selected_jobs) > 0 do %>
      <div class="row mb-3">
        <div class="col-12">
          <div class="alert alert-info d-flex justify-content-between align-items-center">
            <span><%= MapSet.size(@selected_jobs) %> job(s) selected</span>
            <div class="btn-group btn-group-sm">
              <button
                class="btn btn-warning"
                phx-click="bulk_retry"
                phx-value-job_ids={Enum.join(@selected_jobs, ",")}
              >
                Retry Selected
              </button>
              <button
                class="btn btn-danger"
                phx-click="bulk_delete"
                phx-value-job_ids={Enum.join(@selected_jobs, ",")}
              >
                Delete Selected
              </button>
            </div>
          </div>
        </div>
      </div>
    <% end %>

    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Jobs (<%= @total_count %>)</h5>
            <div class="btn-group btn-group-sm">
              <button class="btn btn-outline-secondary" phx-click="select_all">Select All</button>
              <button
                class={"btn #{if MapSet.size(@selected_jobs) > 0, do: "btn-secondary", else: "btn-outline-secondary"}"}
                phx-click="deselect_all"
                disabled={MapSet.size(@selected_jobs) == 0}
              >
                Deselect All
              </button>
            </div>
          </div>
          <div class="card-body">
            <div class="table-responsive">
              <table class="table table-sm table-hover">
                <thead>
                  <tr>
                    <th style="width: 30px;">
                      <input type="checkbox" />
                    </th>
                    <th>ID</th>
                    <th>Queue</th>
                    <th>State</th>
                    <th>Job Class</th>
                    <th>Created At</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for job <- @jobs do %>
                    <tr>
                      <td>
                        <input
                          type="checkbox"
                          checked={MapSet.member?(@selected_jobs, to_string(job.id))}
                          phx-click="toggle_job_selection"
                          phx-value-job_id={job.id}
                        />
                      </td>
                      <td>
                        <code class="small">
                          <%= String.slice(to_string(job.id), 0..8) %>...
                        </code>
                      </td>
                      <td><%= job.queue_name || "default" %></td>
                      <td>
                        <% state = Job.calculate_state(job) %>
                        <span class={"badge bg-#{Formatters.state_badge_class(state)}"}>
                          <%= state %>
                        </span>
                      </td>
                      <td><%= job.job_class %></td>
                      <td><%= Formatters.format_datetime(job.inserted_at) %></td>
                      <td>
                        <div class="btn-group btn-group-sm">
                          <button
                            class="btn btn-sm btn-outline-primary"
                            phx-click="view_job"
                            phx-value-job_id={job.id}
                          >
                            View
                          </button>
                          <%= if state == :discarded do %>
                            <button
                              class="btn btn-sm btn-outline-warning"
                              phx-click="retry_job"
                              phx-value-job_id={job.id}
                            >
                              Retry
                            </button>
                          <% end %>
                          <button
                            class="btn btn-sm btn-outline-danger"
                            phx-click="delete_job"
                            phx-value-job_id={job.id}
                          >
                            Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>

            <%= if @total_count > @per_page do %>
              <nav>
                <ul class="pagination pagination-sm justify-content-center">
                  <%= for page_num <- pagination_pages(@current_page, @total_count, @per_page) do %>
                    <li class={"page-item #{if page_num == @current_page, do: "active", else: ""}"}>
                      <a class="page-link" href="#" phx-click="navigate" phx-value-page={page_num}>
                        <%= page_num %>
                      </a>
                    </li>
                  <% end %>
                </ul>
              </nav>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp pagination_pages(current_page, total_count, per_page) do
    total_pages = div(total_count + per_page - 1, per_page)

    start_page = max(1, current_page - 2)
    end_page = min(total_pages, current_page + 2)

    Enum.to_list(start_page..end_page)
  end
end
