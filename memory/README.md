# memory/

This directory is the project's institutional memory — where we record
**conflicts, bugs, version decisions, and the reasoning behind non-obvious
choices** so future-you (or an AI agent) doesn't re-derive them.

## Files

| File | What goes in it |
|------|-----------------|
| `known-issues.md` | Bugs / conflicts / footguns actually hit, with root cause + fix. One row per issue. |
| `decisions.md` | Architecture Decision Records (ADRs): *why* a choice was made. Numbered `D0xx`. |
| `versions.md` | Version upgrade history: what bumped when, and why. |

## When to write here

- You hit a bug or conflict during setup **on any machine** → add a row to `known-issues.md`.
- You make a design choice that isn't obvious from the code (e.g. "brew is unpinned by design", "force:yes wipes local nvim edits") → add an ADR to `decisions.md`.
- You bump a pinned version in `vars/versions.yml` → append a line to `versions.md`.

## Conventions

- `decisions.md` ADRs are referenced from code comments as `D0xx` (e.g. `# D002`).
- `known-issues.md` rows reference the fixing commit hash when applicable.
- Keep entries dated (`YYYY-MM-DD`) so decay is visible.
