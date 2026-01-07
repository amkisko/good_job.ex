defmodule HabitTracker.MixProject do
  use Mix.Project

  def project do
    [
      app: :habit_tracker,
      version: "0.1.0",
      elixir: "~> 1.18",
      elixir_paths: elixir_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {HabitTracker.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixir_paths(:test), do: ["lib", "test/support"]
  defp elixir_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:phoenix_html, "~> 4.3"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.5"},
      # GoodJob
      {:good_job, path: "../.."},
      # Phlex and StyleCapsule (from hex)
      {:phlex, "~> 0.2.0"},
      {:style_capsule, "~> 0.8.0"},
      # Tailwind
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      # JavaScript bundling
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      # Database
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21"},
      {:ecto_psql_extras, "~> 0.7"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.build": ["style_capsule.build", "tailwind habit_tracker", "esbuild habit_tracker"],
      "assets.deploy": ["style_capsule.build", "tailwind habit_tracker --minify", "esbuild habit_tracker --minify", "phx.digest"]
    ]
  end
end
