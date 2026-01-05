defmodule MonorepoExampleWeb.Router do
  use MonorepoExampleWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MonorepoExampleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Pipeline for LiveDashboard - needs session and CSRF for socket connection
  pipeline :dashboard do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MonorepoExampleWeb.Layouts, :dashboard}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Pipeline for health checks - minimal, no authentication
  pipeline :api do
    plug :accepts, ["json", "text"]
  end

  scope "/", MonorepoExampleWeb do
    pipe_through :browser

    live "/", JobsLive, :index
    post "/jobs/enqueue", JobsController, :enqueue
  end

  # Health check endpoints (no authentication required)
  scope "/", MonorepoExampleWeb do
    pipe_through :api

    get "/health", HealthController, :check
    get "/health/status", HealthController, :status
  end

  # GoodJob Live Dashboard
  scope "/" do
    pipe_through :dashboard

    live_dashboard "/dashboard",
      metrics: nil,
      ecto_repos: [MonorepoExample.Repo],
      additional_pages: [
        good_job: GoodJob.Web.LiveDashboardPage
      ]
  end
end
