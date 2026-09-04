# Ruby GoodJob parity import, iteration 1

Later pass 20260904114000: tests ran, iteration 1 re-audit closed, iteration 2 imported nothing.

## Decisions

Port only protocol, schema, and correctness pieces that passed audit. Skip Ruby-only surfaces (ActiveRecord unscoped yield, Fiber isolation, Puma adapter_class, Arel, JRuby, Tapioca, Stimulus UI, Continuation jobs, probe_handler deprecation).

Import this iteration:

- discarded plus job_class index from Ruby GoodJob 1795, as a new additive migration so already-applied 1.0.1 parity indexes stay as shipped
- queue_select_limit default 1000 from Ruby GoodJob 1762, matching claim and performer fallbacks that already capped at 1000
- dashboard job and batch list order by inserted_at DESC, id DESC from Ruby GoodJob 1749 so OFFSET pages do not skip or repeat rows that share created_at

Skip this iteration: AmbiguousColumn unscoped yield (1768), Process.stale? nil updated_at (1764), preserve created_at on retry (1789). Elixir claim already qualifies candidate ids; process updated_at is NOT NULL; retry updates the same row.

Iteration 2 skip (audited, not imported): handled_exceptions (1748) is ActiveJob thread-crash policy, not Elixir supervisor rescue; InterruptedError (1750) is a Ruby error-string alias and Elixir already has InterruptError as discard; lock-strategy lifecycle (1756) is already on Process.stale? via lock_type; throttle without label (1760) and multi-rule labels (1700) need a separate concurrency-key design; dashboard tsvector LEFT cap (1769) does not apply because Elixir search uses ILIKE on job_class and serialized_params, not error tsvector; dequeue_query_sort (1645) is a new dequeue contract; adding the current job to a batch (1746) is a batch API expansion; advisory unlock stickiness (1736) is AR connection pinning; amkisko-only Ruby branches stay out.

Amkisko-only Ruby branches (audited-support, custom-environment-name) stay out until a later pass.

## Effects

Tests for the config default failed before the default change (left nil, right 1000). Dashboard pagination and discarded job-class filter tests were added first. Implementation is on patch/ruby-parity-discarded-index-and-select-limit. Nothing committed in this pass.

MIX_ENV=test mix test.reset then mix test test/good_job/config_test.exs test/good_job/web/data_loader_test.exs: 44 tests, 0 failures. mix test: 918 tests, 0 failures.

Iteration 1 re-audit: no open findings that block the three imports. Pipeline database stage: additive index is IF NOT EXISTS, create migration and install template match. Resource and budget: queue_select_limit 1000 is a named dequeue ceiling, not a measured RSS claim. Trace and identification: no new identifiers. Contract: dashboard OFFSET order is now unique on (inserted_at, id). Boundary and control skipped: library, database plant, no physical actuators. Product-surface and privacy skipped: no copy change. Learned-systems skipped: no trained model.

## Next

Distill into CHANGELOG.md when cutting the next version. Do not bump mix.exs until asked. Commit and PR only when asked.

Open later: handled_exceptions as an Elixir-shaped config if operators need UndefinedFunctionError discarded by default; bounded dashboard search if ILIKE on serialized_params hits real load; lock-strategy job-row lifecycle if hybrid session unlock leaks after finish.

## Source

- Ruby good_job repository HEAD 2d8ebb19
- Ruby 1795 discarded job_class index
- Ruby 1762 queue_select_limit default 1000
- Ruby 1749 dashboard order created_at, id
