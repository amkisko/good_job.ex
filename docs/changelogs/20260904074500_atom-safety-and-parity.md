# Atom safety, URL parsing, dashboard links, and Ruby parity for 1.0.1

## Decisions

Patch 1.0.1 folds Unreleased Ruby parity with atom-safety and audit fixes. Hex 1.0.0 already shipped, so mix.exs moves to 1.0.1.

Job class strings and symbol-like payload values use String.to_existing_atom. Unknown Elixir.* classes raise instead of intern. DATABASE_URL query keys are allowlisted. configure_repo uses the loaded OTP application. LiveDashboard build_uri uses URI.encode_query.

Dequeue order and parity indexes were already implemented on main; this release notes them.

## Effects

Operators get encoded dashboard links and a bounded URL parser. Cross-language payloads cannot grow the atom table through unique class or symbol strings. Existing 1.0.0 Hex pin ~> 1.0.0 still matches this patch.

## Next

Publish and tag only after commit and a clean usr/bin/release.exs run.

## Source

- usr/docs/issues/20260904074500_engineering-audit-release-1-0-1.md
- usr/docs/issues/20260730141004_persisted-payload-atom-safety.md
- CHANGELOG.md heading 1.0.1
