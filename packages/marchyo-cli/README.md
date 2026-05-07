# marchyo-cli

Two binaries built from one Bun + TypeScript + Ink monorepo:

- **`marchyo`** — user CLI shipped to end users via the `modules/nixos/cli.nix` system module
- **`marchyoctl`** — developer CLI shipped only inside the devenv shell (`devenv.nix`)

## Layout

```
packages/
  core/      shared library (state IO, schema, nix wrapper, flake detection)
  user-cli/  marchyo entrypoint
  dev-cli/   marchyoctl entrypoint
```

## State model

The user CLI persists settings as JSON at `/etc/marchyo/cli-state.json`. The
NixOS module `modules/nixos/cli-state.nix` reads that file and merges values
into `config.marchyo.*` with `lib.mkDefault` priority — hand-written flake
configuration always wins.

Reading absolute paths outside a flake's source tree requires **impure**
evaluation, so `marchyo rebuild` invokes `nixos-rebuild --impure` automatically.
Pure flake checks (`nix flake check`) treat the missing/unreadable file as
empty state via `builtins.tryEval` guards.

## First-cut commands

| Binary       | Command                                  | Purpose                                    |
|--------------|------------------------------------------|--------------------------------------------|
| `marchyo`    | `status`                                 | Ink dashboard of current config + system   |
| `marchyo`    | `theme get`                              | Print current theme variant                |
| `marchyo`    | `theme set <dark\|light> [--rebuild]`    | Persist theme variant; optionally rebuild  |
| `marchyo`    | `rebuild [-n,--dry-run]`                 | `nixos-rebuild switch --impure --flake`    |
| `marchyoctl` | `scaffold module <name>`                 | New module + import + stub eval test       |
| `marchyoctl` | `options search <q>`                     | Fuzzy-search `marchyo.*` option tree (TUI) |

## Standard flags (both binaries)

Following the [Jylhis CLI/TUI guidelines](https://github.com/jylhis/design):

- `-F, --format <text|json>` — output format (`text` default; `json` is scriptable / a11y-friendly)
- `--no-color` (or `NO_COLOR=1`) — disable color
- `--plain` — strip color, glyphs, animation; use word prefixes (`ok:`, `error:`) instead of `✓`/`✗`
- `--no-animation` — disable spinners
- `--no-input` — disable interactive prompts (also auto-set under `CI`)
- `-q, --quiet` — suppress non-error output
- `-v, --verbose` — increase verbosity (repeatable)

Output discipline: data goes to **stdout**, diagnostics (`✓ ok`, `✗ Error:`, `! Warning:`, `i info`) go to **stderr**. Exit codes: `0` success, `1` runtime failure, `2` usage error.

## Local development

```bash
cd packages/marchyo-cli
bun install
bun run typecheck
bun test
bun packages/user-cli/src/cli.tsx --help
bun packages/dev-cli/src/cli.tsx --help
```

## Nix packaging — known follow-up

`packages/marchyo-cli/package.nix` builds both binaries via `bun build --compile`.
It uses a fixed-output derivation to vendor `node_modules` from `bun.lock`, with
the hash currently set to `lib.fakeHash`. To finish wiring the package into CI:

1. Run `nix build .#legacyPackages.x86_64-linux.marchyo-cli` locally
2. Replace `outputHash = lib.fakeHash;` in `package.nix` with the suggested hash
3. Re-add `marchyo-cli` to `mkPackages` in `outputs.nix`
4. Flip `marchyo.cli.enable = true` in the reference VM (`sharedNixosConfig`)

Until then, `marchyo.cli.enable` defaults to `true` for downstream consumers
but is explicitly disabled in the marchyo flake's own reference configuration
so CI's toplevel build doesn't try to materialize the placeholder hash.
