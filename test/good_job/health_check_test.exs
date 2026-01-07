defmodule GoodJob.HealthCheckTest do
  use GoodJob.Testing.JobCase

  alias GoodJob.HealthCheck

  setup do
    original_config = Application.get_env(:good_job, :config, %{})

    on_exit(fn ->
      Application.put_env(:good_job, :config, original_config)
    end)

    :ok
  end

  test "check returns status map when database is reachable" do
    Application.put_env(:good_job, :config, %{
      repo: GoodJob.TestRepo,
      execution_mode: :inline,
      enable_listen_notify: false
    })

    assert {:ok, status} = HealthCheck.check()
    assert status[:database] == :connected
    assert status[:supervisor] == :not_configured
    assert status[:schedulers] == :not_configured
    assert status[:notifier] == :not_configured
  end

  test "status returns healthy for successful checks" do
    Application.put_env(:good_job, :config, %{
      repo: GoodJob.TestRepo,
      execution_mode: :inline,
      enable_listen_notify: false
    })

    assert HealthCheck.status() == "healthy"
  end

  test "check reports optional components as not running when configured" do
    Application.put_env(:good_job, :config, %{
      repo: GoodJob.TestRepo,
      execution_mode: :external,
      enable_listen_notify: true
    })

    assert {:ok, {:supervisor, :not_running}} = HealthCheck.check_supervisor()
    assert {:ok, {:schedulers, :not_configured}} = HealthCheck.check_schedulers()
    assert {:ok, {:notifier, :not_running}} = HealthCheck.check_notifier()
  end
end
