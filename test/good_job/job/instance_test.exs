defmodule GoodJob.Job.InstanceTest do
  use ExUnit.Case, async: true

  alias GoodJob.Job.Instance

  defmodule TestJob do
    use GoodJob.Job

    @impl GoodJob.Behaviour
    def perform(args) do
      {:ok, Map.get(args, :data, "default")}
    end
  end

  describe "new/3" do
    test "creates a job instance" do
      instance = Instance.new(TestJob, %{data: "test"}, queue: "test")
      assert instance.job_module == TestJob
      assert instance.args == %{data: "test"}
      assert instance.options == [queue: "test"]
    end

    test "uses defaults for args and options" do
      instance = Instance.new(TestJob)
      assert instance.job_module == TestJob
      assert instance.args == %{}
      assert instance.options == []
    end
  end

  describe "perform/1" do
    test "executes job with args" do
      instance = Instance.new(TestJob, %{data: "hello"})
      result = Instance.perform(instance)
      assert result == {:ok, "hello"}
    end

    test "works with MyJob.new().perform() pattern" do
      # This tests ActiveJob pattern: MyJob.new(args).perform
      # In Elixir, we use Instance.perform(MyJob.new(args))
      job = TestJob.new(%{data: "test"})
      result = Instance.perform(job)
      assert result == {:ok, "test"}
    end

    test "handles non-map args" do
      defmodule TestJobWithStringArgs do
        @behaviour GoodJob.Behaviour

        def perform(args) when is_binary(args) do
          {:ok, "received: #{args}"}
        end
      end

      instance = Instance.new(TestJobWithStringArgs, "string_args")
      result = Instance.perform(instance)
      assert result == {:ok, "received: string_args"}
    end

    test "raises if module doesn't implement perform/1" do
      instance = Instance.new(String, %{})

      assert_raise RuntimeError, ~r/does not implement perform\/1/, fn ->
        Instance.perform(instance)
      end
    end
  end
end
