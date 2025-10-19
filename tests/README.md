# Marchyo Testing Infrastructure

This directory contains comprehensive tests for the Marchyo NixOS flake, organized into **lightweight checks** and **VM-based tests**.

## Test Organization

Tests are separated into two categories for optimal performance:

### Lightweight Checks (`lightweight/`)
**Fast tests that run during `nix flake check`** - Complete in under 1 minute total.

These tests validate configuration correctness without booting VMs:
- `eval-nixos-modules` - Verify NixOS modules evaluate without errors
- `eval-home-modules` - Verify Home Manager modules evaluate without errors
- `eval-custom-options` - Test custom `marchyo.*` options are properly defined
- `eval-desktop-module` - Verify desktop module can be enabled
- `eval-development-module` - Verify development module can be enabled
- `eval-all-features` - Test all feature flags work together without conflicts
- `integration-module-eval` - Ensure no infinite recursion in module system

### VM-Based Tests (`nixos/`, `home/`, `integration/`)
**Slow tests requiring manual execution** - Each takes 1-5 minutes and ~2GB RAM.

These tests boot full VMs to validate runtime behavior:

#### NixOS VM Tests (`nixos/`)
- `nixos-desktop` - Desktop environment with Hyprland
- `nixos-development` - Development tools (Docker, GitHub CLI, buildah)
- `nixos-users` - User configuration options
- `nixos-git` - Git system-level installation

#### Home Manager VM Tests (`home/`)
- `home-git` - Git and git-lfs configuration
- `home-packages` - Home Manager package installation (btop, fastfetch)

#### Integration VM Tests (`integration/`)
- `integration-all-features` - All feature flags enabled together in a running system

## Running Tests

### Quick Validation (Recommended)
```bash
# Run all lightweight checks - completes in under 1 minute
nix flake check
```

This runs:
- All lightweight module evaluation tests
- Code formatting checks (treefmt)
- Flake evaluation

**This is the recommended workflow for rapid iteration and CI.**

### Run VM Tests (Manual)
```bash
# Run a specific VM test
nix build .#vmTests.x86_64-linux.nixos-desktop --print-build-logs

# Run all VM tests (takes 15-30 minutes)
nix build .#vmTests.x86_64-linux.nixos-desktop \
         .#vmTests.x86_64-linux.nixos-development \
         .#vmTests.x86_64-linux.nixos-users \
         .#vmTests.x86_64-linux.nixos-git \
         .#vmTests.x86_64-linux.home-git \
         .#vmTests.x86_64-linux.home-packages \
         .#vmTests.x86_64-linux.integration-all-features
```

### List Available Tests
```bash
# List lightweight checks
nix eval .#checks.x86_64-linux --apply builtins.attrNames

# List VM tests
nix eval .#vmTests.x86_64-linux --apply builtins.attrNames
```

### Performance Comparison
| Test Type | Command | Time | Resource Usage |
|-----------|---------|------|----------------|
| **Lightweight** | `nix flake check` | <1 minute | Minimal |
| **Single VM test** | `nix build .#vmTests.x86_64-linux.nixos-desktop` | 1-5 minutes | ~2GB RAM |
| **All VM tests** | Build all vmTests | 15-30 minutes | ~2GB RAM per parallel job |

## Test Output

### Lightweight Tests
Lightweight tests use `pkgs.runCommand` and `nix-instantiate` to verify module evaluation:
- Fast execution (seconds)
- Minimal resource usage
- Clear pass/fail output
- Errors show specific evaluation issues

### VM Tests
VM tests boot full virtual machines and run test scripts:
- Slower execution (1-5 minutes each)
- Higher resource usage (~2GB RAM per test)
- Detailed VM console output
- Test script execution logs

## Development Guidelines

### Adding Lightweight Evaluation Tests
**Preferred for most tests** - Fast and catches configuration errors early.

1. Add test to `tests/lightweight/default.nix`
2. Use `pkgs.runCommand` with `nix-instantiate --eval`
3. Test module evaluation without booting a VM

Example:
```nix
eval-my-module = pkgs.runCommand "test-my-module" { } ''
  ${pkgs.nix}/bin/nix-instantiate --eval --strict \
    -E '(import ${pkgs.path}/nixos/lib/eval-config.nix {
      modules = [
        ${nixosModules}
        {
          marchyo.myModule.enable = true;
          # Minimal required config
          boot.loader.grub.enable = false;
          fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
          system.stateVersion = "25.11";
        }
      ];
    }).config.system.build.toplevel.drvPath' > /dev/null

  touch $out
'';
```

### Adding VM-Based Tests
**Use sparingly** - Only when you need to test runtime behavior.

1. Create test in `tests/nixos/default.nix`, `tests/home/default.nix`, or `tests/integration/default.nix`
2. Use `pkgs.testers.runNixOSTest` framework
3. Import required modules
4. Write test script to verify runtime behavior

Example:
```nix
my-vm-test = pkgs.testers.runNixOSTest {
  name = "marchyo-my-vm-test";

  nodes.machine = { ... }: {
    imports = [ nixosModules ];
    marchyo.myModule.enable = true;
    # Required minimal config
    boot.loader.grub.enable = false;
    fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
    system.stateVersion = "25.11";
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("systemctl status my-service")
  '';
};
```

## Continuous Integration

**Recommended CI workflow** - Only run lightweight checks by default:

```yaml
# Example GitHub Actions workflow
- name: Quick validation
  run: nix flake check

# Optional: Run VM tests on schedule or manual trigger
- name: Full VM test suite
  if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
  run: |
    nix build .#vmTests.x86_64-linux.nixos-desktop \
             .#vmTests.x86_64-linux.integration-all-features
```

**Benefits:**
- Fast feedback on PRs (<1 minute)
- Catches configuration errors early
- Minimal CI resource usage
- VM tests run on-demand for deeper validation

## Performance Notes

### Test Type Comparison
| Type | Speed | Resource Usage | When to Use |
|------|-------|----------------|-------------|
| **Lightweight** | Seconds | Minimal | Default, every commit |
| **VM Tests** | 1-5 min each | ~2GB RAM | Manual, pre-release, scheduled |

### Optimization Tips
- Use `nix flake check` for rapid iteration
- Run specific VM tests only when needed
- Use `--max-jobs` to parallelize VM test runs
- Leverage Nix cache to avoid rebuilding

## Troubleshooting

### Lightweight Test Fails
```bash
# Check flake evaluation
nix flake show

# Run specific lightweight test with details
nix build .#checks.x86_64-linux.eval-nixos-modules --print-build-logs
```

### VM Test Fails or Hangs
```bash
# Run with verbose logging
nix build .#vmTests.x86_64-linux.nixos-desktop --print-build-logs

# Check for infinite loops in configuration
nix eval .#nixosConfigurations.test.config --show-trace
```

### Force Rebuild
```bash
# Lightweight test
nix build .#checks.x86_64-linux.eval-nixos-modules --rebuild

# VM test
nix build .#vmTests.x86_64-linux.nixos-desktop --rebuild
```

## Test Coverage

### Current Coverage

**Lightweight checks** (configuration validation):
- ✅ NixOS module evaluation
- ✅ Home Manager module evaluation
- ✅ Custom options (`marchyo.*`)
- ✅ Desktop module configuration
- ✅ Development module configuration
- ✅ All feature flags enabled together
- ✅ No infinite recursion in module system

**VM tests** (runtime behavior):
- ✅ Desktop environment (Hyprland, fonts, greetd)
- ✅ Development tools (Docker, GitHub CLI, buildah)
- ✅ User configuration
- ✅ Git system-level installation
- ✅ Home Manager git configuration
- ✅ Home Manager package installation
- ✅ Full integration with all features

### Recommended Test Strategy

1. **For new modules**: Add lightweight evaluation test first
2. **For runtime behavior**: Add targeted VM test only if needed
3. **For integration**: Use lightweight evaluation tests when possible
4. **Default workflow**: `nix flake check` before every commit
