# Contributing to Marchyo

Thank you for considering contributing to Marchyo! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Style](#code-style)
- [Module Guidelines](#module-guidelines)
- [Testing Requirements](#testing-requirements)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

- Be respectful and constructive in discussions
- Focus on the technical merits of contributions
- Help newcomers learn the Nix ecosystem
- Report security vulnerabilities privately

## Getting Started

### Prerequisites

- NixOS 24.05+ or Nix package manager with flakes enabled
- Git configured with your name and email
- Familiarity with Nix language and NixOS modules

### Development Environment

1. Clone the repository:

```bash
git clone https://github.com/Jylhis/marchyo.git
cd marchyo
```

2. Enter the development environment (if devenv is set up):

```bash
nix develop
# or if using direnv:
direnv allow
```

3. Verify your setup:

```bash
nix flake check
```

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

### 2. Make Changes

- Keep changes focused and atomic
- Test changes incrementally
- Follow existing code patterns

### 3. Format Code

```bash
nix fmt
```

This runs `nixpkgs-fmt` on all Nix files.

### 4. Validate Changes

```bash
# Check flake evaluation
nix flake check

# Build affected configurations
nix build .#nixosModules.default

# Run specific tests
nix build .#checks.x86_64-linux.your-test
```

### 5. Commit Changes

```bash
git add <files>
git commit -m "type(scope): description"
```

See [Commit Messages](#commit-messages) for format details.

## Code Style

### Nix Code

- **Formatting**: Use `nixpkgs-fmt` (run via `nix fmt`)
- **Line Length**: Aim for 100 characters, hard limit at 120
- **Indentation**: 2 spaces, no tabs
- **Naming**: Use camelCase for attribute names, kebab-case for file names

### Module Structure

Every module should follow this pattern:

```nix
{ lib, config, pkgs, ... }:
let
  cfg = config.marchyo.moduleName;
in
{
  options.marchyo.moduleName = {
    enable = lib.mkEnableOption "module description";

    # Additional options with:
    # - Proper type specifications
    # - Clear descriptions
    # - Sensible defaults
    # - Example values
  };

  config = lib.mkIf cfg.enable {
    # Implementation
  };
}
```

### Documentation

- All options must have descriptions
- Complex options should include examples
- Use proper Markdown in descriptions
- Document breaking changes in comments

Example:

```nix
option = lib.mkOption {
  type = lib.types.str;
  default = "default-value";
  example = "example-value";
  description = ''
    Clear description of what this option does.

    Multiple paragraphs if needed.
  '';
};
```

## Module Guidelines

### NixOS Modules (`modules/nixos/`)

- Use `lib.mkDefault` for overridable defaults
- Use `lib.getExe` for executable paths
- Avoid hardcoded paths
- Respect feature flags (desktop, development, etc.)
- Test on minimal systems

### Home Manager Modules (`modules/home/`)

- Must work without root privileges
- Should integrate with system configuration when possible
- Use `config.programs.*` for program configuration
- Keep user-specific customization

### Generic Modules (`modules/generic/`)

- Must work in both NixOS and Home Manager contexts
- Only use overlapping options
- No system-specific or user-specific code

### Creating a New Module

1. Choose the appropriate directory (nixos/home/generic)
2. Create the module file: `modules/category/module-name.nix`
3. Import it in `modules/category/default.nix`
4. Add options under `marchyo.*` namespace
5. Write tests in `tests/category/`
6. Document in `docs/modules-reference.md`

## Testing Requirements

### Required Tests

All new features must include tests:

- **NixOS modules**: VM test in `tests/nixos/`
- **Home Manager modules**: VM test in `tests/home/`
- **Integration features**: Test in `tests/integration/`

### Writing Tests

Use the NixOS testing framework:

```nix
{
  pkgs,
  nixosModules,
  ...
}:
{
  my-feature = pkgs.testers.runNixOSTest {
    name = "marchyo-my-feature";

    nodes.machine = { ... }: {
      imports = [ nixosModules ];
      marchyo.myFeature.enable = true;
    };

    testScript = ''
      start_all()
      machine.wait_for_unit("multi-user.target")

      # Your test assertions
      machine.succeed("test command")
    '';
  };
}
```

### Running Tests

```bash
# Run all tests
nix flake check

# Run specific test
nix build .#checks.x86_64-linux.test-name

# Run with logs
nix build .#checks.x86_64-linux.test-name --print-build-logs
```

## Commit Messages

### Format

```
type(scope): brief description

Detailed explanation of changes (optional).

Fixes #123
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

### Scopes

- `nixos`: NixOS modules
- `home`: Home Manager modules
- `dev`: Developer tooling
- `ops`: Operational scripts
- `tests`: Test infrastructure
- Specific module names

### Examples

```
feat(nixos): Add gaming module with Steam support

Adds a new gaming module that configures:
- Steam with proton
- Gamemode for performance
- Gaming-optimized kernel parameters

Closes #42
```

```
fix(home): Correct Hyprland keybinding for workspace switching

The previous keybinding conflicted with terminal shortcuts.
Updated to use Super+Number instead of Alt+Number.
```

```
docs: Add installation guide for existing NixOS systems

Provides step-by-step instructions for integrating Marchyo
into existing NixOS configurations.
```

## Pull Request Process

### Before Submitting

- [ ] Code is formatted (`nix fmt`)
- [ ] All tests pass (`nix flake check`)
- [ ] New features have tests
- [ ] Documentation is updated
- [ ] Commit messages follow guidelines
- [ ] Branch is up to date with main

### PR Template

```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Changes
- Bullet point list of changes

## Testing
How was this tested?

## Breaking Changes
List any breaking changes

## Checklist
- [ ] Code formatted
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Changelog entry (if applicable)
```

### Review Process

1. Automated CI checks must pass
2. At least one maintainer review required
3. Address review feedback
4. Squash commits if requested
5. Maintainer will merge when approved

### After Merge

- Delete your branch
- Update your local main branch
- Check that CI/CD completes successfully

## Adding Dependencies

### Flake Inputs

When adding new flake inputs:

1. Add to `flake.nix` inputs
2. Update `flake.lock` with `nix flake update input-name`
3. Document why the dependency is needed
4. Ensure license compatibility

### Package Dependencies

- Prefer packages from nixpkgs
- Document custom packages in `packages/`
- Provide clear build instructions
- Include license information

## Documentation

### What to Document

- New modules and options
- Configuration examples
- Breaking changes
- Migration guides
- Troubleshooting steps

### Where to Document

- **README.md**: High-level overview and quickstart
- **docs/**: Detailed guides and references
- **Module files**: Option descriptions
- **CHANGELOG.md**: User-facing changes

## Questions?

- Open a [discussion](https://github.com/Jylhis/marchyo/discussions)
- Ask in [issues](https://github.com/Jylhis/marchyo/issues)
- Review existing code for examples

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project.
