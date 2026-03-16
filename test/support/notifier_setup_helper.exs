defmodule GoodJob.Test.Support.NotifierSetup do
  @moduledoc """
  Shared setup for Notifier tests.
  """

  use ExUnit.CaseTemplate

  setup do
    # Ensure repo is configured
    original_config = Application.get_env(:good_job, :config, %{})

    Application.put_env(
      :good_job,
      :config,
      Map.merge(original_config, %{
        repo: GoodJob.TestRepo,
        # Disable to avoid connection issues in tests
        enable_listen_notify: false
      })
    )

    # Stop any existing notifier
    if pid = Process.whereis(GoodJob.Notifier) do
      try do
        GenServer.call(pid, :shutdown, 1000)
      rescue
        _ -> GenServer.stop(pid, :normal, 1000)
      end

      Process.sleep(100)
    end

    on_exit(fn ->
      # Restore original config
      Application.put_env(:good_job, :config, original_config)

      if pid = Process.whereis(GoodJob.Notifier) do
        try do
          GenServer.call(pid, :shutdown, 1000)
        rescue
          _ -> GenServer.stop(pid, :normal, 1000)
        end
      end
    end)

    :ok
  end
end
