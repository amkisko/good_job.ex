defmodule GoodJob.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/amkisko/good_job.ex"

  def project do
    [
      app: :good_job,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs(),
      aliases: aliases(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.json": :test,
        "coveralls.html": :test,
        "test.all": :test,
        credo: :test,
        dialyzer: :test
      ],
      dialyzer: [
        plt_add_apps: [:mix, :ecto, :ecto_sql],
        ignore_warnings: ".dialyzer.ignore-warnings"
      ],
      test_coverage: [
        tool: ExCoveralls,
        ignore_paths: [
          "lib/good_job/web",
          "lib/good_job/testing.ex",
          "lib/good_job/testing"
        ]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {GoodJob.Application, []}
    ]
  end

  defp deps do
    [
      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.20"},

      # JSON
      {:jason, "~> 1.4"},

      # Telemetry
      {:telemetry, "~> 1.3"},

      # Phoenix dependencies (optional, for Phoenix integration)
      {:phoenix, "~> 1.7", optional: true},
      {:phoenix_live_view, "~> 0.20", optional: true},
      {:phoenix_html, "~> 4.0", optional: true},
      {:plug, "~> 1.14", optional: true},
      {:plug_cowboy, "~> 2.6", optional: true},

      # Testing
      {:stream_data, "~> 1.0", only: :test},

      # Code quality
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test, runtime: false},
      {:benchee, "~> 1.0", only: :dev, runtime: false},
      {:benchee_html, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Andrei Makarov"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(
        lib mix.exs README.md CHANGELOG.md LICENSE.md .formatter.exs
        priv/migrations priv/static
      )
    ]
  end

  defp description do
    """
    A concurrent, Postgres-based job queue backend for Elixir.
    Inspired by Ruby's GoodJob, designed for maximum compatibility with PostgreSQL
    and Elixir/OTP best practices.
    """
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "CONTRIBUTING.md",
        "GOVERNANCE.md",
        "SECURITY.md",
        "PUBLISHING.md",
        "MIGRATION_FROM_RUBY.md"
      ],
      groups_for_modules: [
        Core: [
          GoodJob,
          GoodJob.Config,
          GoodJob.Job,
          GoodJob.JobState,
          GoodJob.JobExecutor,
          GoodJob.Executor
        ],
        Scheduling: [
          GoodJob.Scheduler,
          GoodJob.JobPerformer,
          GoodJob.CronManager,
          GoodJob.Cron.Entry,
          GoodJob.Cron.Expression
        ],
        Infrastructure: [
          GoodJob.Repo,
          GoodJob.Notifier,
          GoodJob.AdvisoryLock,
          GoodJob.ProcessTracker,
          GoodJob.Supervisor
        ],
        Features: [
          GoodJob.Batch,
          GoodJob.BatchRecord,
          GoodJob.Concurrency,
          GoodJob.Backoff,
          GoodJob.Cleanup,
          GoodJob.HealthCheck
        ],
        Testing: [
          GoodJob.Testing,
          GoodJob.Testing.RepoCase,
          GoodJob.Testing.JobCase,
          GoodJob.Testing.Assertions,
          GoodJob.Testing.Helpers
        ],
        Web: [
          GoodJob.Web.LiveDashboard,
          GoodJob.Web.LiveDashboardPage
        ],
        Plugins: [
          GoodJob.Plugin,
          GoodJob.Plugins.Pruner,
          GoodJob.Plugins.Lifeline
        ],
        Telemetry: [
          GoodJob.Telemetry
        ]
      ]
    ]
  end

  defp aliases do
    [
      "test.all": ["test", "credo", "dialyzer"],
      quality: ["format --check-formatted", "credo --strict", "dialyzer", "test"],
      "quality.fix": ["format", "credo --strict"],
      ci: ["test", "credo", "dialyzer"],
      "test.ci": [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "credo --strict",
        "test --raise",
        "dialyzer"
      ],
      "test.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
      "test.reset": ["ecto.drop --quiet", "test.setup"],
      release: fn _ -> run_script("usr/bin/release.exs") end,
      analyze: fn _ -> run_script("usr/bin/analyze.exs") end
    ]
  end

  defp run_script(script_path) do
    script_path = Path.expand(script_path, __DIR__)

    unless File.exists?(script_path) do
      Mix.shell().error("Script not found: #{script_path}")
      exit({:shutdown, 1})
    end

    {_, exit_code} = System.cmd("elixir", [script_path], into: IO.stream(:stdio, :line), stderr_to_stdout: true)
    exit_code
  end
end
