defmodule GoodJob.Web.Components.JobDetail do
  @moduledoc """
  Job detail component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.{Job, Web.Formatters}

  def render(assigns) do
    ~H"""
    <%= if @job do %>
      <div class="row">
        <div class="col-12">
          <div class="card">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h5 class="card-title mb-0">Job Details</h5>
              <div class="btn-group btn-group-sm">
                <button
                  class="btn btn-outline-secondary"
                  phx-click="navigate"
                  phx-value-view="jobs"
                >
                  ← Back to Jobs
                </button>
                <button
                  class="btn btn-outline-primary"
                  phx-click="navigate"
                  phx-value-view="overview"
                >
                  ← Overview
                </button>
              </div>
            </div>
            <div class="card-body">
              <div class="row">
                <div class="col-md-6">
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <th>ID</th>
                        <td><code><%= @job.id %></code></td>
                      </tr>
                      <tr>
                        <th>Active Job ID</th>
                        <td><code><%= @job.active_job_id %></code></td>
                      </tr>
                      <tr>
                        <th>Job Class</th>
                        <td><%= @job.job_class %></td>
                      </tr>
                      <tr>
                        <th>Queue</th>
                        <td><%= @job.queue_name || "default" %></td>
                      </tr>
                      <tr>
                        <th>Priority</th>
                        <td><%= @job.priority || 0 %></td>
                      </tr>
                      <tr>
                        <th>State</th>
                        <td>
                          <% state = Job.calculate_state(@job) %>
                          <span class={"badge bg-#{Formatters.state_badge_class(state)}"}>
                            <%= state %>
                          </span>
                        </td>
                      </tr>
                      <tr>
                        <th>Executions</th>
                        <td><%= @job.executions_count || 0 %></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
                <div class="col-md-6">
                  <table class="table table-sm">
                    <tbody>
                      <tr>
                        <th>Created At</th>
                        <td><%= Formatters.format_datetime(@job.inserted_at) %></td>
                      </tr>
                      <tr>
                        <th>Scheduled At</th>
                        <td><%= Formatters.format_datetime(@job.scheduled_at) %></td>
                      </tr>
                      <tr>
                        <th>Performed At</th>
                        <td><%= Formatters.format_datetime(@job.performed_at) %></td>
                      </tr>
                      <tr>
                        <th>Finished At</th>
                        <td><%= Formatters.format_datetime(@job.finished_at) %></td>
                      </tr>
                      <tr>
                        <th>Error</th>
                        <td>
                          <%= if @job.error do %>
                            <pre class="small text-danger"><%= @job.error %></pre>
                          <% else %>
                            <span class="text-muted">None</span>
                          <% end %>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              </div>

              <div class="row mt-3">
                <div class="col-12">
                  <h6>Job Arguments</h6>
                  <pre class="bg-light p-3 rounded"><code><%= inspect(@job.serialized_params, pretty: true) %></code></pre>
                </div>
              </div>

              <div class="row mt-3">
                <div class="col-12">
                  <div class="d-flex gap-2">
                    <% state = Job.calculate_state(@job) %>
                    <%= if state == :discarded do %>
                      <button
                        class="btn btn-warning"
                        phx-click="retry_job"
                        phx-value-job_id={@job.id}
                      >
                        Retry Job
                      </button>
                    <% end %>
                    <button
                      class="btn btn-danger"
                      phx-click="delete_job"
                      phx-value-job_id={@job.id}
                    >
                      Delete Job
                    </button>
                    <%= if state != :discarded do %>
                      <button
                        class="btn btn-secondary"
                        phx-click="discard_job"
                        phx-value-job_id={@job.id}
                      >
                        Discard Job
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>

              <%= if length(@executions) > 0 do %>
                <div class="row mt-4">
                  <div class="col-12">
                    <h6>Execution History</h6>
                    <div class="table-responsive">
                      <table class="table table-sm">
                        <thead>
                          <tr>
                            <th>Started At</th>
                            <th>Finished At</th>
                            <th>Duration</th>
                            <th>Error</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for execution <- @executions do %>
                            <tr>
                              <td><%= Formatters.format_datetime(execution.inserted_at) %></td>
                              <td><%= Formatters.format_datetime(execution.finished_at) %></td>
                              <td><%= Formatters.format_duration(execution.duration) %></td>
                              <td>
                                <%= if execution.error do %>
                                  <pre class="small text-danger"><%= execution.error %></pre>
                                <% else %>
                                  <span class="text-success">Success</span>
                                <% end %>
                              </td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
