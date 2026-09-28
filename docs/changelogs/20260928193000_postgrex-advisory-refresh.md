## Participants

- amkisko

## Decisions

- Relock postgrex on the library mix.lock to 0.22.4 so EEF-CVE-2026-66838 / CVE-2026-66838 / GHSA-3gww-3f36-2388 is patched.
- Relock example apps to postgrex 0.22.4 on the same 0.22 line.
- Do not add this advisory to hex ignore_advisories. A patched Hex release already exists.
- Keep mix.exs at ~> 0.22. CHANGELOG.md gets no Unreleased bullet. This is a lockfile advisory refresh, not a public library contract change.

## Effects

- Library mix.lock: postgrex 0.22.4.
- Example mix.lock files: postgrex 0.22.4 (habit_tracker and monorepo_example/elixir also refreshed transitive jason, db_connection, decimal, and telemetry as part of that resolve).
- Local mix hex.audit after the library bump exited 0.

## Source

- docs/dependencies/20260928193000_postgrex-cve-2026-66838.md
- https://github.com/amkisko/good_job.ex/actions/runs/35741164575
