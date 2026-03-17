# Versioning

When creating a new release, always bump the **patch** version (e.g. 1.2.0 → 1.2.1) unless the user explicitly asks for a minor or major bump.

Patch versions are not capped at 9 — they increment naturally beyond single digits (e.g. 1.1.9 → 1.1.10 → 1.1.11, up to 100 or beyond).

## Triggering releases via PRs

Releases are created automatically when a PR merges to `main` (via `.github/workflows/auto-release.yml`). The version bump type is controlled by GitHub labels on the PR:

| Label | Effect |
|---|---|
| `release:major` | e.g. `1.2.3` → `2.0.0` |
| `release:minor` | e.g. `1.2.3` → `1.3.0` |
| *(no label)* | e.g. `1.2.3` → `1.2.4` (patch, default) |

When the user asks to create a **minor** or **major** release, add the corresponding label (`release:minor` or `release:major`) to the PR before merging.
