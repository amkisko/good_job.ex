defmodule GoodJob.Web.Components.Navigation do
  @moduledoc """
  Navigation components for GoodJob LiveDashboard (breadcrumbs and navbar).
  """

  use Phoenix.Component

  def breadcrumbs(assigns) do
    ~H"""
    <div class="row mb-2">
      <div class="col-12">
        <nav aria-label="breadcrumb">
          <ol class="breadcrumb mb-0">
            <li class="breadcrumb-item">
              <a href="#" phx-click="navigate" phx-value-view="overview">GoodJob</a>
            </li>
            <%= if @view != :overview do %>
              <li class="breadcrumb-item active" aria-current="page">
                <%= view_title(@view) %>
              </li>
            <% end %>
          </ol>
        </nav>
      </div>
    </div>
    """
  end

  def navbar(assigns) do
    ~H"""
    <div class="row mb-3">
      <div class="col-12">
        <nav class="navbar navbar-expand-lg navbar-light bg-light border rounded p-2">
          <div class="container-fluid p-0">
            <ul class="navbar-nav flex-row flex-wrap gap-2">
              <li class="nav-item">
                <a
                  class={"nav-link #{if @view == :overview, do: "active fw-bold", else: ""}"}
                  href="#"
                  phx-click="navigate"
                  phx-value-view="overview"
                >
                  Overview
                </a>
              </li>
              <li class="nav-item">
                <a
                  class={"nav-link #{if @view == :jobs, do: "active fw-bold", else: ""}"}
                  href="#"
                  phx-click="navigate"
                  phx-value-view="jobs"
                >
                  Jobs
                  <%= if @nav_counts.jobs_count > 0 do %>
                    <span class="badge bg-secondary rounded-pill ms-1">
                      <%= GoodJob.Web.Formatters.format_count(@nav_counts.jobs_count) %>
                    </span>
                  <% end %>
                </a>
              </li>
              <li class="nav-item">
                <a
                  class={"nav-link #{if @view == :cron, do: "active fw-bold", else: ""}"}
                  href="#"
                  phx-click="navigate"
                  phx-value-view="cron"
                >
                  Cron
                  <%= if @nav_counts.cron_entries_count > 0 do %>
                    <span class="badge bg-secondary rounded-pill ms-1">
                      <%= GoodJob.Web.Formatters.format_count(@nav_counts.cron_entries_count) %>
                    </span>
                  <% end %>
                </a>
              </li>
              <li class="nav-item">
                <a
                  class={"nav-link #{if @view == :pauses, do: "active fw-bold", else: ""}"}
                  href="#"
                  phx-click="navigate"
                  phx-value-view="pauses"
                >
                  Pauses
                  <%= if @nav_counts.pauses_count > 0 do %>
                    <span class="badge bg-warning rounded-pill ms-1">
                      <%= GoodJob.Web.Formatters.format_count(@nav_counts.pauses_count) %>
                    </span>
                  <% end %>
                </a>
              </li>
              <li class="nav-item">
                <a
                  class={"nav-link #{if @view == :batches, do: "active fw-bold", else: ""}"}
                  href="#"
                  phx-click="navigate"
                  phx-value-view="batches"
                >
                  Batches
                  <%= if @nav_counts.batches_count > 0 do %>
                    <span class="badge bg-secondary rounded-pill ms-1">
                      <%= GoodJob.Web.Formatters.format_count(@nav_counts.batches_count) %>
                    </span>
                  <% end %>
                </a>
              </li>
              <li class="nav-item">
                <a
                  class={"nav-link #{if @view == :processes, do: "active fw-bold", else: ""}"}
                  href="#"
                  phx-click="navigate"
                  phx-value-view="processes"
                >
                  Processes
                  <%= if @nav_counts.processes_count > 0 do %>
                    <span class={"badge rounded-pill ms-1 #{if @nav_counts.processes_count == 0, do: "bg-danger", else: "bg-secondary"}"}>
                      <%= GoodJob.Web.Formatters.format_count(@nav_counts.processes_count) %>
                    </span>
                  <% end %>
                </a>
              </li>
            </ul>
          </div>
        </nav>
      </div>
    </div>
    """
  end

  defp view_title(:overview), do: "Overview"
  defp view_title(:jobs), do: "Jobs"
  defp view_title(:job_detail), do: "Job Details"
  defp view_title(:cron), do: "Cron Jobs"
  defp view_title(:pauses), do: "Pauses"
  defp view_title(:batches), do: "Batches"
  defp view_title(:processes), do: "Processes"
  defp view_title(_), do: "Unknown"
end
