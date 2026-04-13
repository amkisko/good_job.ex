# CHANGELOG

## 1.0.0

- First stable release, the public API is expected to remain compatible within a given major version.
- Configurable dequeue lock strategy (`:advisory`, `:skiplocked`, `:hybrid`) via `:lock_strategy` / `GOOD_JOB_LOCK_STRATEGY`, with claiming implemented in `GoodJob.Job.Claim` and a `lock_type` column on `good_jobs` (see migration `add_lock_type_to_good_jobs`).
- Optional idle shutdown via `:idle_timeout` / `GOOD_JOB_IDLE_TIMEOUT`, using `GoodJob.IdleTracker` and `GoodJob.IdleShutdown` so the supervision tree can stop after sustained idle; the scheduler reports activity to the tracker.
- Batch improvements: `Batch` accepts `properties` (stored as `serialized_properties`); `Batch.enqueue_all/1` enqueues members through `GoodJob.Bulk` so PostgreSQL `NOTIFY` runs once for the batch; empty batches trigger completion; `Batch.check_completion/2` takes a transaction-level advisory lock on the batch id; `JobExecutor` calls `check_completion` for both `batch_id` and `batch_callback_id` so parent batches finish after callback jobs; `GoodJob.ModuleResolver` resolves callback module name strings safely.
- `GoodJob.enqueue/3` is split into `prepare_enqueue/3` and `commit_enqueue/1` for reuse; job attributes include `batch_callback_id` when set; enqueue options pass `listen_notify` through to `Job.enqueue/2`.
- Expose `GoodJob.Bulk.notify_after_bulk_flush/1` for custom bulk insert paths that suppress per-row NOTIFY and emit a single notification afterward.
- README and COMPATIBILITY copy updates (shared schema and retry wording).
- Respect `enable_pauses` during dequeue by excluding paused queues and job classes stored in `good_job_settings`, replacing the previous no-op `exclude_paused/1` behavior.
- On worker task exit (`:DOWN`), `GoodJob.JobRecovery` clears the job lock and finalizes open execution rows so work is not left blocked until stale-lock or lifeline recovery runs.
- Maintain `executions_count` only in the executor path; `JobPerformer` no longer increments it when claiming jobs, aligning attempt counts with retries and `max_attempts`.
- Throttle stale-lock cleanup in production while performing a sweep on each attempt in the test environment for deterministic tests.
- Resolve the process lock identifier once per scheduler at startup via `ProcessTracker.id_for_lock/0` and reuse it for claims; simplify process-tracker state by removing the prior per-poll lock counter.
- Concurrency-gated enqueue retries on advisory lock contention: `GoodJob.enqueue/3` matches `{:ok, {:error, :lock_failed}}` from Ecto `Repo.transaction/1` (arity 0), with bounded retries and a short delay between attempts.
- `stale_lock_release_after_seconds` / `GOOD_JOB_STALE_LOCK_RELEASE_AFTER_SECONDS` (default 60) configures how old a row lock may be before the periodic stale-lock sweep clears `locked_by_id` (raise for jobs that run longer than a minute without updating lock state).
- Support `listen_notify: false` on `Job.enqueue/2` for bulk inserts and emit a single PostgreSQL `NOTIFY` after the batch transaction commits.
- Parse concurrency limits from `serialized_params` (including `good_job_*` fields and `good_job_concurrency_config`) for jobs enqueued from other runtimes using the same serialization.
- Implement `GoodJob.RepoPool.configure_repo/1` to return `{:ok, after_connect: &GoodJob.RepoPool.set_timeouts/1}` for optional per-connection statement and lock timeouts.

## 0.3.0

- Introduce configurable advisory lock key derivation (lock function and hash strategy)
- Add preserved-job cleanup by max-count limits
- Implement `GoodJob.Bulk` API for buffered/atomic bulk enqueue workflows
- Refine execution mode handling and application startup behavior
- Update core and example dependencies to latest compatible versions

## 0.2.0

- Update dependencies to the latest supported versions

## 0.1.1

- Align Elixir execution semantics with Ruby GoodJob protocol handling
- Improve concurrency limits, throttling, and perform-limit behaviors
- Expand ActiveJob serialization/deserialization coverage and compatibility
- Harden job execution result handling and error propagation
- Improve scheduler and process tracking behavior and test coverage
- Add telemetry formatter coverage and cleanup/batch handling improvements
- Update monorepo example with cross-language concurrency and GlobalID jobs

## 0.1.0

- Initial public release of `good_job.ex`
- PostgreSQL backend with advisory locks for run-once safety
- LISTEN/NOTIFY integration for low-latency job dispatch
- Worker behavior and macro (`use GoodJob.Job`)
- Job state machine with explicit states and transitions
- Execution modes: `:inline`, `:async`, `:async_all`, `:async_server`, `:external`
- Retry backoff strategy with exponential backoff and jitter
- Executor pattern for structured job execution
- Engine pattern (Basic and Inline engines)
- Job timeouts (per-job timeout configuration)
- Testing helpers (`GoodJob.Testing` module)
- Test infrastructure (test/support/repo_case.ex, test/support/job_case.ex)
- Job callbacks (before_enqueue, after_enqueue, before_perform, after_perform, on_error)
- Cleanup functionality
- Setting management (pause/unpause)
- Mix task for installation (`mix good_job.install`)
- Mix aliases (test.ci, test.setup, test.reset, release, analyze)
- Queue management with ordered queues, queue-specific concurrency, and semicolon-separated pools
- Cron job manager implementation
- Batch job operations
- Concurrency controls (per-key limits and throttling)
- ActiveJob API compatibility (`perform_now`, `perform_later`, `set`, `new().perform()`)
