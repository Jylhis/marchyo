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
- `lib.nix` — Shared test helpers (`testNixOS`, `withTestUser`, `minimalConfig`).
- `eval/` — Per-feature evaluation tests, each returning an attrset of named tests.
- `lib-tests.nix` — Library function unit tests.

### Module Tests

Verify NixOS modules evaluate without errors:

| File | Tests |
|------|-------|
| `eval/feature-flags.nix` | `eval-minimal`, `eval-desktop`, `eval-development`, `eval-all-features`, `eval-worktrunk` |
| `eval/themes.nix` | `eval-themes`, `eval-themes-light` |
| `eval/keyboard.nix` | `eval-keyboard`, `eval-keyboard-no-compose` |
| `eval/graphics.nix` | `eval-graphics-{intel,amd,nvidia,prime-offload,prime-sync,legacy}` |
| `eval/defaults.nix` | `eval-defaults-{browser,editor,null,all,jotain}` |
| `eval/tracking.nix` | `eval-tracking-{minimal,shell,git,editor-wakatime,analysis}` |
| `eval/hyprland.nix` | `check-home-hyprland-config` (verifies generated `hyprland.conf` parses) |

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
