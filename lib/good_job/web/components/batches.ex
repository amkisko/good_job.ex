defmodule GoodJob.Web.Components.Batches do
  @moduledoc """
  Batches component for GoodJob LiveDashboard.
  """

  use Phoenix.Component

  alias GoodJob.Web.Formatters

  def render(assigns) do
    ~H"""
    <div class="row">
      <div class="col-12">
        <div class="card">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h5 class="card-title mb-0">Batches (<%= @total_count %>)</h5>
            <button
              class="btn btn-sm btn-outline-primary"
              phx-click="navigate"
              phx-value-view="overview"
            >
              ← Overview
            </button>
          </div>
          <div class="card-body">
            <%= if Enum.empty?(@batches) do %>
              <p class="text-muted">No batches found</p>
            <% else %>
              <div class="table-responsive">
                <table class="table table-sm table-hover">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Description</th>
                      <th>Status</th>
                      <th>Enqueued At</th>
                      <th>Finished At</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for batch <- @batches do %>
                      <tr>
                        <td>
                          <code class="small">
                            <%= String.slice(to_string(batch.id), 0..8) %>...
                          </code>
                        </td>
                        <td><%= batch.description || "-" %></td>
                        <td>
                          <span class={"badge bg-#{batch_status_badge(batch)}"}>
                            <%= batch_status(batch) %>
                          </span>
                        </td>
                        <td><%= Formatters.format_datetime(batch.enqueued_at) %></td>
                        <td><%= Formatters.format_datetime(batch.finished_at) %></td>
                        <td>
                          <%= if batch.discarded_at && is_nil(batch.finished_at) do %>
                            <button
                              class="btn btn-sm btn-warning"
                              phx-click="retry_batch"
                              phx-value-batch_id={batch.id}
                            >
                              Retry
                            </button>
                          <% end %>
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
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp batch_status(batch) do
    cond do
      batch.discarded_at -> "Discarded"
      batch.finished_at -> "Finished"
      true -> "Active"
    end
  end

  defp batch_status_badge(batch) do
    cond do
      batch.discarded_at -> "danger"
      batch.finished_at -> "success"
      true -> "primary"
    end
  end

  defp pagination_pages(current_page, total_count, per_page) do
    total_pages = div(total_count + per_page - 1, per_page)

    start_page = max(1, current_page - 2)
    end_page = min(total_pages, current_page + 2)

    Enum.to_list(start_page..end_page)
  end
end
