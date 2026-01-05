defmodule GoodJob.Web.Components.Processes do
  @moduledoc """
  Processes component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.Web.Formatters

  def render(assigns) do
    ~H"""
    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Active Processes</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="overview"
            >
              ← Overview
            </button>
          </div>
          <div class="card-body">
            <%= if Enum.empty?(@processes) do %>
              <p class="text-muted">No active processes</p>
            <% else %>
              <div class="table-responsive">
                <table class="table table-sm table-hover">
                  <thead>
                    <tr>
                      <th>Process ID</th>
                      <th>Lock Type</th>
                      <th>State</th>
                      <th>Created At</th>
                      <th>Updated At</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for process <- @processes do %>
                      <tr>
                        <td>
                          <code class="small">
                            <%= String.slice(to_string(process.id), 0..8) %>...
                          </code>
                        </td>
                        <td><%= process.lock_type %></td>
                        <td>
                          <pre class="small mb-0"><%= inspect(process.state, pretty: true) %></pre>
                        </td>
                        <td><%= Formatters.format_datetime(process.inserted_at) %></td>
                        <td><%= Formatters.format_datetime(process.updated_at) %></td>
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
