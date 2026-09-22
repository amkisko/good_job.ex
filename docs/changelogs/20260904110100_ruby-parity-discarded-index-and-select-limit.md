# Ruby parity: discarded job-class index, select limit default, dashboard page order

## Decisions

New additive migration add_index_good_jobs_discarded_job_class for (job_class, finished_at) WHERE finished_at IS NOT NULL AND error IS NOT NULL. Same SQL is in the canonical create migration and the install task template. Existing 1.0.1 add_good_job_parity_indexes is left unchanged so it does not re-run.

Config.Defaults.queue_select_limit is 1000. Claim and JobPerformer keep || 1000 as defense when an operator sets nil. Docs and habit_tracker example follow the default.

DataLoader.load_jobs and load_batches order by inserted_at DESC, id DESC so OFFSET pagination is unique when many rows share created_at.

## Effects

Operators who already ran 1.0.1 apply one extra index migration. Advisory dequeue candidate scans stay capped at 1000 unless configured higher. Dashboard job and batch lists no longer skip a twin created in the same microsecond.

## Next

Distill into CHANGELOG.md when cutting the next version. Do not bump mix.exs in this pass.

## Source

- usr/docs/issues/20260904110100_ruby-parity-import-audit.md
- Ruby GoodJob 1795, 1762, 1749
