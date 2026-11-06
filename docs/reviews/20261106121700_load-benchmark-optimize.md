# Load benchmark and hot-path resource cuts

## Participants

Andrei Makarov (@amkisko)

## Decisions

- Add a maintainer load harness under `benchmarks/` that measures wall time, jobs/s, BEAM reductions/runtime/memory, Postgres `pg_stat_database` deltas (proxy for DB CPU and network), relation/WAL growth (storage), and Ecto query counts.
- Prefer `:skiplocked` for high dequeue throughput; keep `:advisory` as the compatibility default.
- Fix dequeue bugs that blocked skiplocked/hybrid under real load (UUID bind, negative `send_after`, hybrid `checkout` arity).
- Cut enqueue cost via `GoodJob.Bulk` `insert_all` chunks; cut dequeue scheduling chatter by filling free scheduler slots in one poll.
- Treat extra worker threads past ~16 as a contention risk on a single queue, not a free win.
- Claim multiple `:skiplocked` / `:hybrid` rows per poll with multi-row `SKIP LOCKED` (`claim_many` / `perform_next_batch`, cap 64).
- When `preserve_job_records` is false, delete the job and its `good_job_executions` rows together on finish.
- Document the high-throughput recipe in README and COMPATIBILITY without flipping the Elixir `:advisory` default.

## Effects

### Harness

- `benchmarks/load.exs` + `benchmarks/support/metrics.exs`
- `MIX_ENV=dev mix bench.load` (alias) or `mix run benchmarks/load.exs`
- Env knobs: `SCENARIO=matrix|drain|enqueue_only`, `JOBS`, `THREADS`, `LOCK`, `BULK`, `PRESERVE`, `POOL_SIZE`, `GOOD_JOB_BENCH_DB`
- JSON under `benchmarks/output/` (gitignored)

### Observed baseline (matrix, 2000 jobs, 16 threads, before hot-path cuts)

| Scenario | jobs/s | Ecto queries | notes |
| --- | ---: | ---: | --- |
| enqueue single | ~2220 | ~4005 | 2 round-trips/job |
| enqueue bulk (row inserts) | ~6675 | ~2008 | one txn, still N inserts |
| drain advisory | ~166 | ~38k | very high `tup_fetch` |
| drain hybrid | ~629 | ~21k | |
| drain skiplocked | ~961 | ~16k | best drain strategy |

### After iterative cuts (same machine, representative runs)

| Scenario | jobs/s | Ecto queries | notes |
| --- | ---: | ---: | --- |
| enqueue bulk `insert_all` | ~15k–21k | ~10–25 / 10k jobs | ~3–4× vs prior bulk |
| enqueue single 10k | ~4040 | ~10005 | unchanged path |
| drain skiplocked 2k / 16 threads | ~835 | ~22k | after slot-fill + claim RETURNING |
| drain skiplocked 5k / 32 threads | ~555 | ~63k | more threads ≠ linear gain |
| drain skiplocked 20k / 64 threads | ~158 | ~268k | thrash: pool/contention |
| drain skiplocked 10k / 16 threads, `preserve_job_records: false` | ~339 | ~90k | `tup_fetch` collapses vs preserve-on |

### After multi-row claim + execution delete + VACUUM ANALYZE (quiet local host)

Matrix `JOBS=2000 THREADS=16 PRESERVE=false` (output `benchmarks/output/20261106145530_load.json`):

| Scenario | jobs/s | Ecto queries | notes |
| --- | ---: | ---: | --- |
| enqueue bulk | ~23383 | ~10 | insert_all |
| drain advisory | ~128–133 | ~34k | still weakest |
| drain hybrid | ~426–573 | ~24k | |
| drain skiplocked | ~646–650 | ~21–22k | multi-row claim |
| heavy skiplocked 4k silent | ~477 | ~46k | better than earlier ~343 at similar size |

Cold 10k skiplocked / 16 threads after `VACUUM (ANALYZE)`:

| Preserve | jobs/s | tup_fetch | exec_rel_delta_kb | queries |
| --- | ---: | ---: | ---: | ---: |
| false | ~311 | ~129k | ~2808 | ~119k |
| true | ~279 | ~3.0M | ~7296 | ~130k |

Host-relative only; not an SLO. Recipe and caveats live in README / COMPATIBILITY.

### Code changes landed with this review

- `GoodJob.Job.Claim`: dump UUID params for raw SQL; `RETURNING gj.*` + `repo.load/2`; fix hybrid `Repo.checkout/1` (0-arity); `claim_many/6` multi-row `SKIP LOCKED`.
- `GoodJob.JobPerformer.perform_next_batch/4` + scheduler fill via batch claim.
- `GoodJob.Config.poll_interval_ms/0`: never pass a negative delay to `send_after/3` (dev async `-1` → 100 ms).
- `GoodJob.Poller`: continuous poll delay safe for negative intervals.
- `GoodJob.Bulk`: chunked `insert_all` instead of per-row insert in one transaction.
- `GoodJob.JobPerformer`: drop redundant post-update `get!`; stale-lock sweep every 50 claims.
- `GoodJob.JobExecutor`: skip re-`get!` after claim; when not preserving, delete job + executions together.
- `GoodJob.PubSub`: cache Phoenix.PubSub availability in `:persistent_term`.
- `GoodJob.Scheduler`: fill free slots in one `:poll` / on task completion without `send_after(0)` chatter.
- Docs: README high-throughput section; COMPATIBILITY recipe (default remains `:advisory`).

## Next

- Optional: skip inserting `good_job_executions` at perform-start when `preserve_job_records` is false (today: insert then delete on success).
- Re-check numbers on another host/CI Postgres before treating them as published baselines.

## Source

- `benchmarks/load.exs`
- `benchmarks/support/metrics.exs`
- Sample JSON: `benchmarks/output/*_load.json` (local only)
- README high-throughput section; COMPATIBILITY “High-throughput recipe”
- Related parity work: `docs/issues/20261106101000_ruby-v5-runtime-defaults.md`
