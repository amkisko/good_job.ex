# Ruby v5 prep: label concurrency and claims behavior

## Participants

Andrei Makarov (@amkisko)

## Decisions

After schema parity (`good_job_concurrency_claims` present), implement runtime that matches Ruby GoodJob 4.21–4.22 progressive enhancement:

- Prefer concurrency rules scoped by label (`label:` key prefix `label:` in claims).
- Keep `concurrency_key` enqueue/perform checks working for shared Ruby/Elixir databases; emit a clear Logger warning when only key-based concurrency is used (Elixir-shaped deprecation).
- When the claims table exists: grant / wait / promote on perform_limit paths; release on job finish and process cleanup.
- Do not drop `concurrency_key` column or reject key-only jobs until Elixir 2.0 / Ruby v5 alignment.

## Effects

Claims grant/wait/promote, label-scoped enqueue/perform, finish/crash release, id=active_job_id alignment, and COMPATIBILITY guidance landed on `feature/ruby-4-24-and-v5-prep`. `mix test` at that point: 923 tests, 0 failures.

## Next

Operator README examples can expand later. Runtime defaults continue in `docs/issues/20261106101000_ruby-v5-runtime-defaults.md`.

## Source

- `docs/plans/20261106095035_ruby-4-24-and-v5-parity.md`
- Ruby README “Migrating from concurrency keys to labels”
- Ruby `GoodJob::ConcurrencyClaim`
