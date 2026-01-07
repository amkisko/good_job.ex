defmodule GoodJob.SchedulerTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias GoodJob.{CleanupTracker, Job, Repo, Scheduler}

  defmodule TransactionErrorRepo do
    def transaction(_fun), do: {:error, :boom}
    def get(schema, id), do: GoodJob.TestRepo.get(schema, id)
    def insert!(changeset), do: GoodJob.TestRepo.insert!(changeset)
    def update!(changeset), do: GoodJob.TestRepo.update!(changeset)
  end

  defmodule CountServer do
    use GenServer

    def start_link(replies) do
      GenServer.start_link(__MODULE__, replies)
    end

    def init(replies) do
      {:ok, replies}
    end

    def handle_call(:get_running_tasks_count, _from, [reply | rest]) do
      {:reply, reply, rest}
    end

    def handle_call(:get_running_tasks_count, _from, []) do
      {:reply, {:ok, 0}, []}
    end
  end

  setup do
    repo = Repo.repo()
    Sandbox.checkout(repo)
    Sandbox.mode(repo, {:shared, self()})

    original_config = Application.get_env(:good_job, :config, %{})
    original_debug = System.get_env("DEBUG")

    on_exit(fn ->
      Application.put_env(:good_job, :config, original_config)

      if original_debug do
        System.put_env("DEBUG", original_debug)
      else
        System.delete_env("DEBUG")
      end
    end)

    Application.put_env(:good_job, :config, Map.put(original_config, :repo, GoodJob.TestRepo))

    :ok
  end

  defp base_state(overrides \\ %{}) do
    cleanup_tracker = CleanupTracker.new(cleanup_interval_seconds: false, cleanup_interval_jobs: false)

    Map.merge(
      %{
        queue_string: "default",
        max_processes: 1,
        task_supervisor: self(),
        running_tasks: %{},
        shutdown: false,
        cleanup_tracker: cleanup_tracker,
        wait_pid: nil
      },
      overrides
    )
  end

  defp insert_test_job(attrs \\ %{}) do
    defaults = %{
      active_job_id: Ecto.UUID.generate(),
      job_class: "GoodJob.Protocol.TestJobs.PaymentJob",
      queue_name: "default",
      priority: 0,
      serialized_params: %{"arguments" => [%{}]},
      executions_count: 0
    }

    attrs = Map.merge(defaults, attrs)

    %Job{}
    |> Job.changeset(attrs)
    |> Repo.repo().insert!()
  end

  test "init registers with poller when running" do
    queue_string = "init-#{System.unique_integer([:positive])}"

    {poller_pid, started_poller?} =
      case Process.whereis(GoodJob.Poller) do
        nil ->
          {:ok, pid} = GoodJob.Poller.start_link(poll_interval: 2, recipients: [])
          {pid, true}

        pid ->
          {pid, false}
      end

    on_exit(fn ->
      if started_poller? and Process.alive?(poller_pid) do
        GenServer.stop(poller_pid, :normal, 1000)
      end
    end)

    {:ok, state} = Scheduler.init({queue_string, 1, false, false})

    try do
      Process.sleep(20)
      recipients = :sys.get_state(poller_pid).recipients
      assert self() in recipients
    after
      if Process.alive?(state.task_supervisor) do
        Process.exit(state.task_supervisor, :shutdown)
      end
    end
  end

  test "init skips poller registration when poller is missing" do
    queue_string = "init-missing-#{System.unique_integer([:positive])}"
    {:ok, state} = Scheduler.init({queue_string, 1, false, false})

    assert state.queue_string == queue_string

    if Process.alive?(state.task_supervisor) do
      Process.exit(state.task_supervisor, :shutdown)
    end
  end

  test "poll returns early when shutdown is true" do
    state = base_state(%{shutdown: true})
    assert {:noreply, ^state} = Scheduler.handle_info(:poll, state)
  end

  test "poll schedules when at max processes" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, poll_interval: 1})

    state = base_state(%{running_tasks: %{make_ref() => {nil, %Job{id: "job"}}}})

    assert {:noreply, ^state} = Scheduler.handle_info(:poll, state)
    assert_receive :poll, 1500
  end

  test "poll schedules when no job is available" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, poll_interval: 1})

    state = base_state(%{running_tasks: %{}, max_processes: 1})

    assert {:noreply, ^state} = Scheduler.handle_info(:poll, state)
    assert_receive :poll, 1500
  end

  test "poll logs and schedules when JobPerformer returns an error" do
    Application.put_env(:good_job, :config, %{repo: TransactionErrorRepo, poll_interval: 1})

    state = base_state(%{running_tasks: %{}, max_processes: 1})

    assert {:noreply, ^state} = Scheduler.handle_info(:poll, state)
    assert_receive :poll, 1500
  end

  test "poll starts task when job found and capacity remains" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, poll_interval: 1})

    {:ok, task_supervisor} = Task.Supervisor.start_link()
    _job = insert_test_job()

    state = base_state(%{max_processes: 2, task_supervisor: task_supervisor})

    {:noreply, state} = Scheduler.handle_info(:poll, state)
    assert map_size(state.running_tasks) == 1
    assert_receive :poll, 500

    {ref, result} =
      receive do
        {ref, result} -> {ref, result}
      after
        1000 -> flunk("Expected task completion message")
      end

    assert {:noreply, state} = Scheduler.handle_info({ref, result}, state)
    assert map_size(state.running_tasks) == 0
    assert_receive :poll, 500

    if Process.alive?(task_supervisor) do
      Supervisor.stop(task_supervisor, :normal, 1000)
    end
  end

  test "poll starts task and schedules with full capacity" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, poll_interval: 1})

    {:ok, task_supervisor} = Task.Supervisor.start_link()
    _job = insert_test_job(%{queue_name: "full"})

    state = base_state(%{queue_string: "full", max_processes: 1, task_supervisor: task_supervisor})

    {:noreply, state} = Scheduler.handle_info(:poll, state)
    assert map_size(state.running_tasks) == 1
    assert_receive :poll, 1500

    if Process.alive?(task_supervisor) do
      Supervisor.stop(task_supervisor, :normal, 1000)
    end
  end

  test "task completion handles error result with logging when DEBUG=1" do
    System.put_env("DEBUG", "1")

    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}

    state = base_state(%{running_tasks: %{ref => {task, job}}})

    assert {:noreply, state} = Scheduler.handle_info({ref, {:error, :boom}}, state)
    assert map_size(state.running_tasks) == 0
  end

  test "task crash logs when DEBUG=1" do
    System.put_env("DEBUG", "1")

    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}

    state = base_state(%{running_tasks: %{ref => {task, job}}})

    assert {:noreply, state} = Scheduler.handle_info({:DOWN, ref, :process, self(), :boom}, state)
    assert map_size(state.running_tasks) == 0
  end

  test "task crash skips logging when DEBUG is not set" do
    System.delete_env("DEBUG")

    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}

    state = base_state(%{running_tasks: %{ref => {task, job}}})

    assert {:noreply, state} = Scheduler.handle_info({:DOWN, ref, :process, self(), :boom}, state)
    assert map_size(state.running_tasks) == 0
  end

  test "task completion ignores unknown refs" do
    ref = make_ref()
    state = base_state()

    assert {:noreply, ^state} = Scheduler.handle_info({ref, {:ok, :ok}}, state)
  end

  test "task crash ignores unknown refs" do
    ref = make_ref()
    state = base_state()

    assert {:noreply, ^state} = Scheduler.handle_info({:DOWN, ref, :process, self(), :boom}, state)
  end

  test "task completion triggers cleanup and resets tracker" do
    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}

    cleanup_tracker = CleanupTracker.new(cleanup_interval_seconds: false, cleanup_interval_jobs: -1)

    state = base_state(%{running_tasks: %{ref => {task, job}}, cleanup_tracker: cleanup_tracker})

    assert {:noreply, state} = Scheduler.handle_info({ref, {:ok, :ok}}, state)
    assert map_size(state.running_tasks) == 0
    assert state.cleanup_tracker.job_count == 0
  end

  test "cleanup errors are rescued and logged" do
    Application.put_env(:good_job, :config, %{repo: TransactionErrorRepo, poll_interval: 2})

    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}

    cleanup_tracker = CleanupTracker.new(cleanup_interval_seconds: false, cleanup_interval_jobs: -1)

    state = base_state(%{running_tasks: %{ref => {task, job}}, cleanup_tracker: cleanup_tracker})

    assert {:noreply, state} = Scheduler.handle_info({ref, {:ok, :ok}}, state)
    assert map_size(state.running_tasks) == 0

    Process.sleep(50)
  end

  test "tasks_complete and tasks_timeout reply to caller" do
    ref_ok = make_ref()
    ref_timeout = make_ref()
    from_ok = {self(), ref_ok}
    from_timeout = {self(), ref_timeout}

    state = base_state(%{wait_pid: self()})

    assert {:noreply, state} = Scheduler.handle_info({:tasks_complete, from_ok}, state)
    assert_receive {^ref_ok, :ok}

    assert {:noreply, _state} = Scheduler.handle_info({:tasks_timeout, from_timeout}, state)
    assert_receive {^ref_timeout, :timeout}
  end

  test "shutdown? and get_running_tasks_count expose state" do
    state = base_state(%{shutdown: true, running_tasks: %{make_ref() => {nil, %Job{id: "job"}}}})

    assert {:reply, true, ^state} = Scheduler.handle_call(:shutdown?, self(), state)
    assert {:reply, {:ok, 1}, ^state} = Scheduler.handle_call(:get_running_tasks_count, self(), state)
  end

  test "shutdown returns ok immediately when no running tasks" do
    state = base_state(%{running_tasks: %{}})

    assert {:reply, :ok, state} = Scheduler.handle_call({:shutdown, 1}, self(), state)
    assert state.shutdown == true
  end

  test "shutdown waits for tasks and returns timeout" do
    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}
    from = {self(), make_ref()}

    state = base_state(%{running_tasks: %{ref => {task, job}}})

    assert {:noreply, state} = Scheduler.handle_call({:shutdown, 0}, from, state)
    assert state.shutdown == true

    assert {:noreply, _state} = Scheduler.handle_info({:tasks_timeout, from}, state)
    assert_receive {_, :timeout}
  end

  test "shutdown waits for tasks and returns ok with finite timeout" do
    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}
    from = {self(), make_ref()}

    state = base_state(%{running_tasks: %{ref => {task, job}}})

    assert {:noreply, state} = Scheduler.handle_call({:shutdown, 1}, from, state)
    assert state.shutdown == true

    assert {:noreply, _state} = Scheduler.handle_info({:tasks_complete, from}, state)
    assert_receive {_, :ok}
  end

  test "shutdown waits for tasks and returns ok with infinite timeout" do
    ref = make_ref()
    task = %Task{ref: ref, pid: self(), owner: self(), mfa: {Kernel, :self, 0}}
    job = %Job{id: "job-id"}
    from = {self(), make_ref()}

    state = base_state(%{running_tasks: %{ref => {task, job}}})

    assert {:noreply, state} = Scheduler.handle_call({:shutdown, -1}, from, state)
    assert state.shutdown == true

    assert {:noreply, _state} = Scheduler.handle_info({:tasks_complete, from}, state)
    assert_receive {_, :ok}
  end

  test "shutdown uses configured default timeout" do
    Application.put_env(:good_job, :config, %{repo: GoodJob.TestRepo, shutdown_timeout: 0})

    queue_string = "shutdown-default-#{System.unique_integer([:positive])}"

    {:ok, scheduler} =
      Scheduler.start_link(queue_string: queue_string, max_processes: 0)

    assert :ok == GenServer.call(scheduler, :shutdown, 2000)

    if Process.alive?(scheduler) do
      GenServer.stop(scheduler, :normal, 1000)
    end
  end

  test "wait_for_tasks_loop returns ok when no running tasks" do
    {:ok, server} = CountServer.start_link([])
    assert :ok == Scheduler.wait_for_tasks_loop(%{}, 0, server)
  end

  test "wait_for_tasks_loop returns timeout when remaining timeout hits zero" do
    {:ok, server} = CountServer.start_link([{:ok, 1}])
    assert :timeout == Scheduler.wait_for_tasks_loop(%{task: :busy}, 0, server)
  end

  test "wait_for_tasks_loop sleeps when remaining timeout is finite" do
    {:ok, server} = CountServer.start_link([{:ok, 1}, {:ok, 0}])
    assert :ok == Scheduler.wait_for_tasks_loop(%{task: :busy}, 1000, server)
  end

  test "wait_for_tasks_loop sleeps for infinity timeouts" do
    {:ok, server} = CountServer.start_link([{:ok, 1}, {:ok, 0}])
    assert :ok == Scheduler.wait_for_tasks_loop(%{task: :busy}, :infinity, server)
  end

  test "wait_for_tasks_loop handles unexpected replies" do
    {:ok, server} = CountServer.start_link([:error, {:ok, 0}])
    assert :ok == Scheduler.wait_for_tasks_loop(%{task: :busy}, 1000, server)
  end

  test "wait_for_tasks_loop handles unexpected replies with zero timeout" do
    {:ok, server} = CountServer.start_link([:error])
    assert :timeout == Scheduler.wait_for_tasks_loop(%{task: :busy}, 0, server)
  end
end
