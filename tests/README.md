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

`eval/` holds one file per feature (`feature-flags.nix`, `themes.nix`,
`keyboard.nix`, `graphics.nix`, `defaults.nix`, `hyprland.nix`, and many more),
each returning an attrset of named tests that assert a NixOS config evaluates
without errors for a given feature combination. All are auto-discovered. Use the
`nix eval … builtins.attrNames` command above to list the current test names.

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
