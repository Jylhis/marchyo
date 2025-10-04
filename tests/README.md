# Marchyo Testing Infrastructure

This directory contains comprehensive tests for the Marchyo NixOS flake, organized into four categories:

## Test Categories

### 1. NixOS VM Tests (`nixos/`)
Tests for NixOS system-level configurations using the NixOS testing framework.

**Tests:**
- `nixos-basic` - Basic system configuration with timezone and locale
- `nixos-desktop` - Desktop environment with Hyprland
- `nixos-development` - Development tools (Docker, GitHub CLI, buildah)
- `nixos-users` - User configuration options
- `nixos-git` - Git system-level installation

### 2. Home Manager Tests (`home/`)
Tests for Home Manager user-level configurations.

**Tests:**
- `home-shell` - Bash and readline configuration
- `home-git` - Git and git-lfs configuration
- `home-fontconfig` - Font configuration
- `home-packages` - Home Manager package installation (btop, fastfetch)

### 3. Package Tests (`packages/`)
Tests for custom packages in the flake.

**Tests:**
- `package-plymouth-theme-builds` - Verify plymouth theme builds correctly
- `package-plymouth-theme-structure` - Verify theme directory structure
- `package-plymouth-theme-metadata` - Test build failure handling (intentional failure)
- `package-plymouth-theme-valid` - Verify package metadata and attributes

### 4. Integration Tests (`integration/`)
End-to-end tests combining multiple modules.

**Tests:**
- `integration-nixos-home` - NixOS + Home Manager integration
- `integration-multi-user` - Multiple users with separate configurations
- `integration-all-features` - All feature flags enabled together
- `integration-module-eval` - Module evaluation without infinite recursion

## Running Tests

### Run All Tests
```bash
nix flake check
```

This runs all checks including:
- All test suites
- Code formatting checks (treefmt)
- Flake evaluation

### Run Specific Test
```bash
# Run a single test
nix build .#checks.x86_64-linux.nixos-basic

# Run with build logs
nix build .#checks.x86_64-linux.integration-nixos-home --print-build-logs

# Run on different architecture
nix build .#checks.aarch64-linux.home-shell
```

### Run Test Category
```bash
# Run all NixOS tests
nix build .#checks.x86_64-linux.nixos-basic \
         .#checks.x86_64-linux.nixos-desktop \
         .#checks.x86_64-linux.nixos-development \
         .#checks.x86_64-linux.nixos-users \
         .#checks.x86_64-linux.nixos-git

# Run all package tests
nix build .#checks.x86_64-linux.package-plymouth-theme-builds \
         .#checks.x86_64-linux.package-plymouth-theme-structure \
         .#checks.x86_64-linux.package-plymouth-theme-valid
```

### List All Available Tests
```bash
nix eval .#checks.x86_64-linux --apply builtins.attrNames
```

## Test Output

### VM Tests
VM tests (NixOS and Home Manager) create a virtual machine and run test scripts. Output includes:
- VM console output
- Test script execution logs
- Success/failure status

Successful tests produce a result symlink in the current directory.

### Package Tests
Package tests are simple derivations that verify:
- Build success
- File structure
- Metadata correctness

Failed tests will show specific assertion failures.

## Development Guidelines

### Adding New NixOS Tests
1. Create test in `tests/nixos/default.nix`
2. Use `pkgs.testers.runNixOSTest` framework
3. Import `nixosModules.default` in the machine configuration
4. Write test script to verify system behavior

Example:
```nix
my-test = pkgs.testers.runNixOSTest {
  name = "marchyo-my-test";

  nodes.machine = { ... }: {
    imports = [ nixosModules.default ];
    # Your configuration
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    # Your test assertions
  '';
};
```

### Adding Home Manager Tests
1. Create test in `tests/home/default.nix`
2. Use `pkgs.testers.runNixOSTest` with home-manager module
3. Import `homeModules.default` in user configuration
4. Test as specific user using `su - username -c 'command'`

### Adding Package Tests
1. Create test in `tests/packages/default.nix`
2. Use `pkgs.runCommand` for simple checks
3. Use `pkgs.testers.testBuildFailure` to verify error handling

### Adding Integration Tests
1. Create test in `tests/integration/default.nix`
2. Combine multiple modules
3. Test cross-module interactions
4. Verify feature flag combinations work correctly

## Continuous Integration

Tests are automatically registered as flake checks and can be run in CI:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: nix flake check
```

## Performance Notes

- **VM tests** are slow (1-5 minutes each) as they boot a full VM
- **Package tests** are fast (seconds) as they're simple derivations
- Use `--max-jobs` to parallelize test runs
- VM tests consume significant memory (~2GB per test)

## Troubleshooting

### Test Fails to Start
Ensure the flake can evaluate:
```bash
nix flake show
```

### VM Test Hangs
Increase timeout or check for infinite loops in configuration.

### Build Cache
Tests are cached in the Nix store. To force rebuild:
```bash
nix build .#checks.x86_64-linux.my-test --rebuild
```

## Test Coverage

Current coverage:
- **NixOS Modules**: Core modules tested (boot, desktop, development, git, users)
- **Home Manager**: Shell, git, fontconfig, package installation
- **Packages**: Plymouth theme package
- **Integration**: Multi-module interactions, feature flag combinations

Areas for expansion:
- Hardware-specific configurations
- Network configurations
- Security module tests
- Media and office module tests
