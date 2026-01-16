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

- `default.nix` - Entry point combining all tests
- `module-tests.nix` - Module evaluation tests
- `lib-tests.nix` - Library function unit tests

### Module Tests

Verify NixOS modules evaluate without errors:

| Test | Description |
|------|-------------|
| `eval-minimal` | Minimal NixOS modules import |
| `eval-desktop` | Desktop feature flag |
| `eval-development` | Development feature flag |
| `eval-all-features` | All features together |
| `eval-themes` | Theme configurations |
| `eval-keyboard` | Keyboard layouts and IME |
| `eval-graphics-*` | GPU configurations (Intel, AMD, NVIDIA, PRIME) |

### Library Tests

Unit tests for `lib/colors.nix` functions (`hexToDec`, `toRgb`, `toRgba`, etc.).

## Adding Tests

### Module Evaluation Test

Add to `module-tests.nix`:

```nix
eval-my-feature = testNixOS "my-feature" (withTestUser {
  marchyo.myFeature.enable = true;
});
```

### Library Test

Add to `lib-tests.nix`:

```nix
test-my-function = pkgs.runCommand "test-my-function" { } ''
  result=$(nix eval --raw --expr '(import ../lib { inherit (pkgs) lib; }).myFunction "input"')
  [[ "$result" == "expected" ]] || exit 1
  touch $out
'';
```
