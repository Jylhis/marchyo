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
NixOS module `modules/nixos/cli-state.nix` reads a **top-level** `marchyoCliState`
option (intentionally outside the `marchyo.*` namespace — declaring it under
`marchyo.cli.*` would create a self-cycle in module evaluation) and merges its
contents into `config.marchyo.*` with `lib.mkDefault` priority. Hand-written
flake configuration always wins.

The marchyo flake itself never reads absolute paths, so `nix flake check`
remains pure. End-user flakes opt in by reading the JSON sidecar themselves:

```nix
# in your flake.nix configuration module
{
  marchyoCliState =
    builtins.fromJSON (builtins.readFile /etc/marchyo/cli-state.json);
}
```

Then rebuild with `nixos-rebuild switch --impure --flake ...`. The
`marchyo rebuild` CLI command passes `--impure` automatically.

## Change model: runtime-first with `--apply` / `--revert`

Every *mutating* command follows one three-mode contract (generalizing the
current `theme set --rebuild`):

- **default = runtime** — apply live (`hyprctl`, `systemctl --user`,
  `hyprsunset`, `makoctl`, symlink swap) and persist an ephemeral override under
  `~/.local/state/marchyo/runtime.json` so it survives `hyprctl reload`. Instant,
  no rebuild.
- **`--apply`** — additionally write the key into `/etc/marchyo/cli-state.json`
  (the `marchyoCliState` → `marchyo.*` path, merged at `mkDefault`) and run
  `nixos-rebuild`. Survives reboot; hand-written flake config still wins.
- **`--revert`** — undo: drop the runtime override (reload the declarative
  value) and/or delete the persisted key + rebuild.

Declarative-only commands (`install`/`webapp`/`security`) have no runtime path —
they always take the `--apply` route (edit `cli-state.json`, then rebuild).

## Commands

### The 1.0 surface (frozen)

As of 1.0, command names, arguments, flags, and exit codes are **stable
until 2.0** (additions allowed in 1.x; renames/removals are not). The
contract is enforced by snapshot tests (`packages/user-cli/tests/contract.test.ts`).

| Group       | Commands |
|-------------|----------|
| System      | `status`, `rebuild`, `update`, `upgrade`, `rollback`, `gc`, `diff`, `debug` |
| Theme       | `theme list\|get\|set <name>\|next`, `bg set\|next` (`dark`/`light` alias the Jylhis pair; `--rebuild` is a deprecated alias for `--apply`) |
| Toggle      | `toggle <name> [on\|off] [--status\|--apply\|--revert]` — gaps, transparency, nightlight, waybar, touchpad, touchscreen, idle, screensaver, notifications, suspend, hybrid-gpu (`--apply`-only) |
| Capture     | `capture screenshot [--target …] [--edit]`, `capture record [--audio …]`, `capture ocr`, `capture color` |
| Menu/launch | `menu [power]`, `keybindings`, `launch <app>`, `focus-or-launch <class>`, `zoom in\|out\|reset`, `monitor scale-cycle\|laptop-toggle` |
| Power       | `lock`, `logout`, `suspend`, `hibernate`, `reboot`, `shutdown`, `powerprofile get\|list\|set` |
| Utilities   | `reminder set\|show\|clear`, `info datetime\|battery`, `transcode [--to …\|--ascii]`, `share [file]`, `font list\|current\|set` |
| Declarative | `install\|remove <feature>`, `webapp add\|rm`, `security enroll fido2\|fingerprint` |
| Plumbing    | `runtime status\|restore`, `completion bash\|zsh\|fish\|man` |

`marchyoctl` (dev shell only): `scaffold module <name>`, `options search <q>`.

Full reference with examples: https://marchyo.org/docs/usage/cli/

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

## Nix packaging

`packages/marchyo-cli/package.nix` builds both binaries via `bun build --compile`,
vendoring `node_modules` from `bun.lock` through a fixed-output derivation (the
`outputHash` is pinned to a real value). The package is wired end to end:

- built in `overlay.nix` (`marchyo-cli = final.callPackage ...`);
- exported from `outputs.nix` `mkPackages` (`packages.<system>.marchyo-cli`);
- installed by `modules/nixos/cli.nix` when `marchyo.cli.enable` (**default
  `true`**); options declared in `modules/nixos/options/cli.nix`; CLI-written
  state merged back via `modules/nixos/cli-state.nix`;
- available to developers through the devenv shell (`devenv.nix`).

After changing dependencies, re-pin the hash: `nix build
.#legacyPackages.x86_64-linux.marchyo-cli`, then update `outputHash` in
`package.nix` with the suggested value.
