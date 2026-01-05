# CHANGELOG

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
