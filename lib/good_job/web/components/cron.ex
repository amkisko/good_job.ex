defmodule GoodJob.Web.Components.Cron do
  @moduledoc """
  Cron jobs component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.Cron.Entry
  alias GoodJob.Web.Formatters

  def render(assigns) do
    ~H"""
    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Cron Jobs</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="overview"
            >
              ← Overview
            </button>
          </div>
          <div class="card-body">
            <div class="table-responsive">
              <table class="table table-sm table-hover">
                <thead>
                  <tr>
                    <th>Key</th>
                    <th>Cron Expression</th>
                    <th>Job Class</th>
                    <th>Queue</th>
                    <th>Next Run</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for entry <- @cron_entries do %>
                    <tr>
                      <td><strong><%= entry.key %></strong></td>
                      <td><code><%= entry.cron %></code></td>
                      <td><%= Formatters.format_job_class(entry.class) %></td>
                      <td><%= entry.queue %></td>
                      <td><%= Formatters.format_datetime(Entry.next_at(entry)) %></td>
                      <td>
                        <span class={"badge bg-#{if entry.enabled, do: "success", else: "secondary"}"}>
                          <%= if entry.enabled, do: "Enabled", else: "Disabled" %>
                        </span>
                      </td>
                      <td>
                        <div class="btn-group btn-group-sm">
                          <%= if entry.enabled do %>
                            <button
                              class="btn btn-outline-warning"
                              phx-click="disable_cron"
                              phx-value-cron_key={entry.key}
                            >
                              Disable
                            </button>
                          <% else %>
                            <button
                              class="btn btn-outline-success"
                              phx-click="enable_cron"
                              phx-value-cron_key={entry.key}
                            >
                              Enable
                            </button>
                          <% end %>
                          <button
                            class="btn btn-outline-primary"
                            phx-click="enqueue_cron"
                            phx-value-cron_key={entry.key}
                          >
                            Enqueue Now
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
