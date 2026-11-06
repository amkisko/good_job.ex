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

    # PubSub is shared; Endpoint only when serving HTTP (mix phx.server / PHX_SERVER=true).
    # This lets Procfile run elixir_worker (mix run --no-halt) and elixir_web (mix phx.server)
    # without binding port 4000 twice. With execution_mode :external, GoodJob starts in the
    # worker process and stays out of the web process.
    serve_web? =
      Application.get_env(:phoenix, :serve_endpoints, false) ||
        System.get_env("PHX_SERVER") in ["1", "true", "TRUE"]

    web_children =
      [
        {Phoenix.PubSub, name: MonorepoExample.PubSub}
      ] ++
        if serve_web? do
          [MonorepoExampleWeb.Endpoint]
        else
          []
        end

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
