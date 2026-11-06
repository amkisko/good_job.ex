# Ruby v5 prep: dequeue sort, threads name, skiplocked path

## Participants

Andrei Makarov (@amkisko)

## Decisions

Land progressive runtime defaults that Ruby schedules for v5 without flipping Elixir production defaults yet:

- Add `dequeue_query_sort` (`:created_at` default today; `:scheduled_at` is the v5-bound path).
- Accept `threads` alongside `max_threads` in pool/scheduler config; prefer `threads` in docs.
- Document rolling migrate advisory → hybrid → skiplocked; keep Elixir default `:advisory` until Ruby v5 / Elixir 2.0.

## Effects

`dequeue_query_sort`, `threads`/`GOOD_JOB_THREADS`, validation, query ordering, and COMPATIBILITY skiplocked rolling-migrate notes landed on `feature/ruby-4-24-and-v5-prep`. Elixir defaults stay `:created_at` and `:advisory`.

## Next

Flip defaults only with Elixir 2.0 / Ruby v5 alignment. Optional: expand README examples.

## Source

- `docs/plans/20261106095035_ruby-4-24-and-v5-parity.md`
- Ruby `Configuration#dequeue_query_sort` and `threads` / `max_threads`
