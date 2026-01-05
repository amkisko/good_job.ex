defmodule HabitTrackerWeb.Router do
  use HabitTrackerWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HabitTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Pipeline for LiveDashboard - needs session and CSRF for socket connection
  pipeline :dashboard do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Pipeline for health checks - minimal, no authentication
  pipeline :api do
    plug :accepts, ["json", "text"]
  end

  scope "/", HabitTrackerWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    live "/habits", HabitsLive, :index
    live "/analytics", AnalyticsLive, :index
    live "/jobs", JobsLive, :index
  end

  # Health check endpoints (no authentication required)
  scope "/", HabitTrackerWeb do
    pipe_through :api

    get "/health", HealthController, :check
    get "/health/status", HealthController, :status
  end

  # GoodJob Live Dashboard
  scope "/" do
    pipe_through :dashboard

    live_dashboard "/dashboard",
      metrics: HabitTrackerWeb.Telemetry,
      ecto_repos: [HabitTracker.Repo],
      additional_pages: [
        good_job: GoodJob.Web.LiveDashboardPage
      ]
  end
end
