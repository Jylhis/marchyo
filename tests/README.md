# Marchyo Tests

Fast evaluation tests that run during `nix flake check` (under 1 minute).

## Running Tests

```bash
# Run all tests
nix flake check

# List available tests
nix eval .#checks.x86_64-linux --apply builtins.attrNames
```

## Test Structure

- `default.nix` — Entry point. Auto-discovers every file in `eval/` and merges the attrsets they return; appends `lib-tests.nix`.
- `lib.nix` — Shared test helpers (`testNixOS`, `testNixOSCheck`, `testNixOSFails`, `withTestUser`, `minimalConfig`). `testNixOSCheck` runs a predicate against the evaluated config, which forces lazily-evaluated values (kernelParams, audit rules, generated config) that plain `testNixOS` leaves as thunks.
- `eval/` — Per-feature evaluation tests, each returning an attrset of named tests.
- `lib-tests.nix` — Library function unit tests.

### Module Tests

Verify NixOS modules evaluate without errors (and, where `testNixOSCheck` is used, assert specific option values):

| File | Tests |
|------|-------|
| `eval/feature-flags.nix` | `eval-minimal`, `eval-desktop`, `eval-development`, `eval-development-no-desktop`, `eval-all-features` |
| `eval/themes.nix` | `eval-themes`, `eval-themes-light`, `eval-themes-paper` |
| `eval/keyboard.nix` | `eval-keyboard`, `eval-keyboard-no-compose`, `eval-keyboard-default-altgr-intl`, `eval-keyboard-plain-us-ralt`, `eval-keyboard-legacy-variant` |
| `eval/graphics.nix` | `eval-graphics-{intel,amd,nvidia,prime-offload,prime-sync,legacy}`, `eval-logitech` |
| `eval/defaults.nix` | `eval-defaults-{browser,editor,null,all,jotain,tui,tui-alt}` |
| `eval/tracking.nix` | `eval-tracking-{minimal,shell,git,editor-wakatime,analysis,auditd,auditd-no-users,grafana-cloud,claude-code,…}` (+ negative tests) |
| `eval/performance.nix` | `eval-performance-tuning-{default,all}` |
| `eval/hyprland.nix` | `eval-hyprland-wallpaper-{enabled,disabled}`, `check-home-hyprland-config` (builds + parses generated `hyprland.conf`) |
| `eval/input-migration.nix` | `eval-fail-input-method-removed` (negative: removed options error) |
| `eval/regressions.nix` | kernelParams merge, disabled-user tracking, desktop gating, media-flag gating |

### Library Tests

`lib-tests.nix` uses `assertTest` for fast unit tests of helper functions.

## Adding Tests

### Module Evaluation Test

Drop into the matching `eval/<feature>.nix`, or create a new file there. Each file is a function:

```nix
{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  eval-my-feature = testNixOS "my-feature" (withTestUser {
    marchyo.myFeature.enable = true;
  });
}
```

The file is auto-discovered — no edit to `default.nix` needed.

### Library Test

Add to `lib-tests.nix`:

```nix
test-my-function = assertTest "my-function" (
  myFunction "input" == "expected"
) "Expected myFunction to return 'expected'";
```
