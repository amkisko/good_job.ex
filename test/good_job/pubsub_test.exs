defmodule GoodJob.PubSubTest do
  use ExUnit.Case

  alias GoodJob.PubSub

  setup do
    original_pubsub_server = Application.get_env(:good_job, :pubsub_server)
    original_config = Application.get_env(:good_job, :config, %{})

    on_exit(fn ->
      Application.put_env(:good_job, :pubsub_server, original_pubsub_server)
      Application.put_env(:good_job, :config, original_config)
    end)

    :ok
  end

  test "broadcasts and subscribes when pubsub is configured" do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: GoodJobPubSubTest})
    Application.put_env(:good_job, :pubsub_server, GoodJobPubSubTest)

    topic = PubSub.subscribe()
    assert topic == "good_job:jobs"

    assert :ok == PubSub.broadcast(:job_created, "job-1")
    assert_receive {:job_created, "job-1"}
  end

  test "broadcast returns :noop for unknown events" do
    assert PubSub.broadcast(:unknown_event, "job-1") == :noop
  end
end
