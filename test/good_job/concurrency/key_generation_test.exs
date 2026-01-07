defmodule GoodJob.Concurrency.KeyGenerationTest do
  use ExUnit.Case, async: false

  alias GoodJob.Repo

  setup do
    _pid = Ecto.Adapters.SQL.Sandbox.checkout(Repo.repo())
    Ecto.Adapters.SQL.Sandbox.mode(Repo.repo(), {:shared, self()})
    :ok
  end

  describe "module-level concurrency key generation" do
    test "generates concurrency_key from job arguments" do
      defmodule UserJob do
        use GoodJob.Job

        def good_job_concurrency_config do
          [total_limit: 2]
        end

        def good_job_concurrency_key(%{user_id: user_id}) do
          "user:#{user_id}"
        end

        def perform(%{user_id: _user_id}) do
          :ok
        end
      end

      # Enqueue without explicitly passing concurrency_key
      {:ok, job1} = UserJob.enqueue(%{user_id: 123})
      assert job1.concurrency_key == "user:123"

      {:ok, job2} = UserJob.enqueue(%{user_id: 123})
      assert job2.concurrency_key == "user:123"

      # Third job should be blocked (total_limit: 2)
      result = UserJob.enqueue(%{user_id: 123})
      assert match?({:error, _}, result)
    end

    test "allows different concurrency keys for different arguments" do
      defmodule ResourceJob do
        use GoodJob.Job

        def good_job_concurrency_config do
          [total_limit: 1]
        end

        def good_job_concurrency_key(%{resource_type: type, resource_id: id}) do
          "#{type}:#{id}"
        end

        def perform(%{resource_type: _type, resource_id: _id}) do
          :ok
        end
      end

      {:ok, job1} = ResourceJob.enqueue(%{resource_type: "user", resource_id: 123})
      assert job1.concurrency_key == "user:123"

      {:ok, job2} = ResourceJob.enqueue(%{resource_type: "order", resource_id: 456})
      assert job2.concurrency_key == "order:456"

      # Different keys should both be allowed (both jobs were successfully enqueued)
      assert job1.concurrency_key != job2.concurrency_key
    end

    test "explicit concurrency_key in opts takes precedence" do
      defmodule OverrideJob do
        use GoodJob.Job

        def good_job_concurrency_key(%{user_id: user_id}) do
          "user:#{user_id}"
        end

        def perform(%{user_id: _user_id}) do
          :ok
        end
      end

      {:ok, job} = OverrideJob.enqueue(%{user_id: 123}, concurrency_key: "custom-key")
      assert job.concurrency_key == "custom-key"
    end

    test "returns nil when no concurrency_key function defined" do
      defmodule NoKeyJob do
        use GoodJob.Job

        def perform(_args) do
          :ok
        end
      end

      {:ok, job} = NoKeyJob.enqueue(%{data: "test"})
      assert job.concurrency_key == nil
    end

    test "supports complex key generation with multiple arguments" do
      defmodule ComplexKeyJob do
        use GoodJob.Job

        def good_job_concurrency_config do
          [total_limit: 2]
        end

        def good_job_concurrency_key(args) do
          user_id = Map.get(args, :user_id) || Map.get(args, "user_id")
          queue = Map.get(args, :queue) || "default"
          "#{queue}:#{user_id}"
        end

        def perform(_args) do
          :ok
        end
      end

      {:ok, job1} = ComplexKeyJob.enqueue(%{user_id: 123, queue: "high"})
      assert job1.concurrency_key == "high:123"

      {:ok, job2} = ComplexKeyJob.enqueue(%{user_id: 456, queue: "high"})
      assert job2.concurrency_key == "high:456"

      # Different user_ids should both be allowed (both jobs were successfully enqueued)
      assert job1.concurrency_key == "high:123"
      assert job2.concurrency_key == "high:456"
    end
  end
end
