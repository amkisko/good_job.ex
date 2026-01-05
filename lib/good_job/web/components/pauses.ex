defmodule GoodJob.Web.Components.Pauses do
  @moduledoc """
  Pauses component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.Web.Formatters

  def render(assigns) do
    ~H"""
    <div class="row mb-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Create Pause</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="overview"
            >
              ← Overview
            </button>
          </div>
          <div class="card-body">
            <form phx-submit="create_pause" class="row g-3">
              <div class="col-md-5">
                <label class="form-label">Queue Name</label>
                <input
                  type="text"
                  name="queue"
                  class="form-control form-control-sm"
                  placeholder="e.g., ex.default"
                />
              </div>
              <div class="col-md-5">
                <label class="form-label">Job Class</label>
                <input
                  type="text"
                  name="job_class"
                  class="form-control form-control-sm"
                  placeholder="e.g., MyApp.Job"
                />
              </div>
              <div class="col-md-2 d-flex align-items-end">
                <button type="submit" class="btn btn-sm btn-primary w-100">Create Pause</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>

    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Active Pauses</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="overview"
            >
              ← Overview
            </button>
          </div>
          <div class="card-body">
            <%= if Enum.empty?(@pauses) do %>
              <p class="text-muted">No active pauses</p>
            <% else %>
              <div class="table-responsive">
                <table class="table table-sm table-hover">
                  <thead>
                    <tr>
                      <th>Type</th>
                      <th>Target</th>
                      <th>Created At</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for pause <- @pauses do %>
                      <tr>
                        <td>
                          <span class="badge bg-info">
                            <%= if pause.queue, do: "Queue", else: "Job Class" %>
                          </span>
                        </td>
                        <td><strong><%= pause.queue || pause.job_class %></strong></td>
                        <td><%= Formatters.format_datetime(pause.inserted_at) %></td>
                        <td>
                          <button
                            class="btn btn-sm btn-danger"
                            phx-click="delete_pause"
                            phx-value-pause_key={pause.key}
                          >
                            Delete
                          </button>
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
