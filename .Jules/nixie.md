# Nixie's Journal

This journal tracks critical learnings, recurring breakages, and workarounds discovered during Nix maintenance cycles.

## Format
## YYYY-MM-DD - [Title]
**Learning:** [Technical insight]
**Action:** [Constraint to apply next time]

## 2026-02-22 - Deprecated 'system' argument in inputs
**Learning:** Several upstream inputs (likely `flake-utils` or via `crane`) still use the deprecated `system` argument instead of `stdenv.hostPlatform.system`, causing evaluation warnings.
**Action:** Ignore this warning for now as it stems from dependencies, but monitor for upstream fixes.
