# Beads Integration

Marchyo uses **beads** (`bd`) for in-repo issue tracking. Issues live in `.beads/` and are tracked alongside the code.

## When to use beads

| Situation | Action |
|-----------|--------|
| Starting work on a bug or feature | `bd new` to create an issue |
| Resuming after a break | `bd ls` to see open issues, `bd show <id>` for context |
| Finishing a task | `bd close <id>` |
| Reporting a finding or blocker | `bd comment <id>` |
| Checking project health | `bd stats` |

## Key commands

```bash
bd new                        # Create a new issue (interactive)
bd ls                         # List open issues
bd ls --all                   # List all issues including closed
bd show <id>                  # Show full issue detail
bd comment <id>               # Add a comment to an issue
bd close <id>                 # Close an issue
bd edit <id>                  # Edit issue title/body
bd stats                      # Summary stats
```

## Issue lifecycle

1. **Open** — active work in progress
2. **Closed** — resolved, verified, or abandoned (with note)

Always close issues with a brief summary of what was done or why it was skipped.

## Session continuity protocol

At the start of a session:
1. Run `bd ls` to see what's open
2. If resuming work, run `bd show <id>` for full context
3. Create a new issue for new work with `bd new`

At the end of a session:
1. Close completed issues with `bd close <id>`
2. Leave open issues with a comment summarizing current state

## Project-specific notes

- **Codebase**: Nix-only (`.nix` files throughout). No TypeScript, Python, or other languages.
- **Tests**: Evaluation-only — no builds needed. Run with `nix flake check` (fast).
- **Formatting**: `nix fmt` before committing (nixfmt + deadnix + statix + shellcheck + yamlfmt via treefmt).
- **Options**: All custom options live in `modules/nixos/options.nix` under `marchyo.*`.
- **Commits**: Use conventional commit format (`feat:`, `fix:`, `chore:`, etc.).
- **No speckit**: Marchyo doesn't use speckit or any test framework beyond Nix evaluation checks.

## Worktree integration

New worktrees get a `.beads/redirect` file pointing to the main repo's `.beads/` directory, so all worktrees share the same issue database. This is set up automatically by the worktrunk `post-create` hook in `.config/wt.toml`.
