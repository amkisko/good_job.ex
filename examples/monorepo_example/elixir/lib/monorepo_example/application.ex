defmodule MonorepoExample.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Check if GoodJob should start automatically
    # GoodJob.Config.start_in_application?() handles both :async and :external modes
    start_good_job? = GoodJob.Config.start_in_application?()

    base_children = [
      MonorepoExample.Repo
    ]

    good_job_children =
      if start_good_job? do
        [GoodJob.Supervisor]
      else
        []
      end

    web_children = [
      # Start PubSub for LiveView
      {Phoenix.PubSub, name: MonorepoExample.PubSub},
      # Start Phoenix Endpoint
      MonorepoExampleWeb.Endpoint
    ]

    children = base_children ++ good_job_children ++ web_children

    opts = [strategy: :one_for_one, name: MonorepoExample.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # Build assets if they don't exist (for first run or production)
        ensure_assets_built()
        {:ok, pid}

      error ->
        error
    end
  end

  defp ensure_assets_built do
    # Check if CSS file exists, if not build assets
    # Assets are built on startup if missing. For development changes, run: mix tailwind monorepo_example_worker
    css_path = Path.join([Application.app_dir(:monorepo_example_worker), "priv", "static", "assets", "css", "app.css"])

    unless File.exists?(css_path) do
      # Build assets using system command (works in running app)
      # This runs in background to avoid blocking startup
      Task.start(fn ->
        try do
          # Get the project root directory
          project_root = Path.expand("../..", __DIR__)

          # Run mix tailwind command
          System.cmd("mix", ["tailwind", "monorepo_example_worker"],
            cd: project_root,
            stderr_to_stdout: true,
            into: IO.stream(:stdio, :line)
          )

          IO.puts("✅ Assets built successfully!")
        rescue
          e ->
            IO.puts("⚠️  Could not build assets: #{inspect(e)}")
            IO.puts("   Run 'mix assets.build' manually to build assets.")
        end
      end)
    end
  end
end
