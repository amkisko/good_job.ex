defmodule MonorepoExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :monorepo_example_worker,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MonorepoExample.Application, []}
    ]
  end

  defp deps do
    # Use environment variable for good_job path in Docker, otherwise relative path
    good_job_path = System.get_env("GOOD_JOB_PATH") || "../../../"

    [
      # Use local good_job dependency
      {:good_job, path: good_job_path},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21"},
      {:jason, "~> 1.4"},
      # Phoenix dependencies for web interface
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:plug_cowboy, "~> 2.7"},
      # Phlex and StyleCapsule for component-based UI
      {:phlex, "~> 0.2"},
      {:style_capsule, "~> 0.8"},
      # Tailwind CSS
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.build": ["tailwind monorepo_example_worker"],
      "assets.deploy": ["tailwind monorepo_example_worker --minify", "phx.digest"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
