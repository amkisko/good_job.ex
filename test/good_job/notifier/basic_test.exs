defmodule GoodJob.Notifier.BasicTest do
  use ExUnit.Case

  alias GoodJob.Notifier

  setup do
    original_config = Application.get_env(:good_job, :config, %{})

    on_exit(fn ->
      Application.put_env(:good_job, :config, original_config)
    end)

    Application.put_env(:good_job, :config, Map.put(original_config, :repo, GoodJob.TestRepo))

    :ok
  end

  test "notify returns :ok when listen/notify is disabled" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, enable_listen_notify: false})
    assert Notifier.notify(%{queue_name: "default"}) == :ok
  end

  test "add_recipient and remove_recipient update state in disabled mode" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, enable_listen_notify: false})
    pid =
      case Process.whereis(Notifier) do
        nil -> start_supervised!(Notifier)
        pid -> pid
      end

    Notifier.add_recipient(self())
    Process.sleep(10)
    assert %{recipients_count: 1} = GenServer.call(pid, :get_state)

    Notifier.remove_recipient(self())
    Process.sleep(10)
    assert %{recipients_count: 0} = GenServer.call(pid, :get_state)
  end

  test "handle_result marks listening state on successful listen" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, notifier_channel: "good_job"})
    state = %Notifier{listening?: false}
    assert {:noreply, new_state} = Notifier.handle_result([%Postgrex.Result{}], state)
    assert new_state.listening? == true
  end

  test "notify/3 delivers messages to recipients" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, notifier_channel: "good_job"})

    state = %Notifier{recipients: [self()], listening?: true, connected?: true}
    payload = Jason.encode!(%{"queue_name" => "default"})

    new_state = Notifier.notify("good_job", payload, state)
    assert new_state.connection_errors == 0
    assert_receive {:good_job_notification, %{"queue_name" => "default"}}
  end
end
