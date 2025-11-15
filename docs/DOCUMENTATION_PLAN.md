# Marchyo Documentation Site Plan

## Research Findings

### Documentation Generation in NixOS Ecosystem

Based on research of major Nix projects (nixpkgs, home-manager, nix.dev), here are the key findings:

#### 1. **Options Documentation**
- **Tool**: `pkgs.nixosOptionsDoc` (formerly `makeOptionsDoc`)
- **Process**:
  1. Evaluate modules with `lib.evalModules`
  2. Pass evaluated options to `nixosOptionsDoc`
  3. Outputs: CommonMark (Markdown), JSON, DocBook
- **Usage Pattern**:
  ```nix
  let
    eval = lib.evalModules {
      modules = [ ./modules/nixos/default.nix ];
    };
    optionsDoc = pkgs.nixosOptionsDoc {
      inherit (eval) options;
    };
  in optionsDoc.optionsCommonMark
  ```

#### 2. **Documentation Rendering**
- **Tool**: `nixos-render-docs` (nrd)
- **Format**: CommonMark Markdown (RFC 0072 standard)
- **Extensions**: NixOS-specific syntax for options, code blocks, admonitions

#### 3. **Static Site Generator**
- **NixOS Unstable Manual**: Uses mdBook
- **Home Manager**: Uses DocBook + custom tooling
- **Trend**: Migration to mdBook in ecosystem
- **Nix Integration**: `nix-mdbook` flake (https://github.com/pbar1/nix-mdbook)

### Tooling Decision

**Selected Stack**:
1. **mdBook** - Rust-based static site generator
   - Fast, simple, widely used in Rust/Nix ecosystems
   - Excellent offline support
   - Clean, readable output
   - Extensible via plugins

2. **nix-mdbook** - Flake library for building mdBook
   - Native Nix integration
   - CI/CD optimized
   - Reproducible builds

3. **nixosOptionsDoc** - Auto-generate module options
   - Official NixOS tooling
   - CommonMark output integrates with mdBook
   - JSON output for advanced use cases

4. **GitHub Pages** - Deployment
   - Free hosting
   - Automatic HTTPS
   - CI/CD integration

---

## Architecture

### Directory Structure

```
docs/
├── book.toml                    # mdBook configuration
├── src/                         # Hand-written documentation
│   ├── SUMMARY.md              # Table of contents
│   ├── index.md                # Landing page
│   ├── tutorials/              # Learning-oriented (Diataxis)
│   │   ├── installation.md
│   │   ├── first-configuration.md
│   │   └── adding-modules.md
│   ├── how-to/                 # Problem-oriented (Diataxis)
│   │   ├── customize-theme.md
│   │   ├── configure-desktop.md
│   │   ├── setup-development.md
│   │   └── troubleshooting.md
│   ├── reference/              # Information-oriented (Diataxis)
│   │   ├── modules/
│   │   │   ├── nixos-options.md      # Auto-generated
│   │   │   ├── home-options.md       # Auto-generated
│   │   │   └── generic-options.md    # Auto-generated
│   │   ├── feature-flags.md
│   │   ├── color-schemes.md
│   │   └── default-apps.md
│   └── explanation/            # Understanding-oriented (Diataxis)
│       ├── architecture.md
│       ├── module-system.md
│       ├── theming-system.md
│       └── design-decisions.md
├── theme/                      # Custom mdBook theme (optional)
│   └── css/
│       └── custom.css
└── build/                      # Build artifacts (gitignored)
```

### Flake Integration

```
flake.nix
├── inputs.mdbook              # nix-mdbook flake
├── packages.docs              # Built documentation
├── packages.docs-serve        # Local dev server
└── apps.serve-docs            # `nix run .#serve-docs`
```

---

## Implementation Plan

### Phase 1: Infrastructure Setup (Week 1)

#### Step 1: Add nix-mdbook to flake
- Add `nix-mdbook` as flake input
- Create `docs/` directory structure
- Initial `book.toml` configuration

#### Step 2: Configure auto-generated options docs
- Create `docs/generate-options.nix`
- Generate NixOS module options
- Generate Home Manager module options
- Generate generic module options

#### Step 3: Set up build system
- Create package derivations for:
  - `packages.docs` - Build documentation
  - `packages.docs-serve` - Development server
- Configure GitHub Actions workflow
- GitHub Pages deployment

### Phase 2: Auto-Generated Reference (Week 2)

#### Options Documentation Generator

Create `docs/generate-options.nix`:

```nix
{ lib, pkgs, ... }:
let
  # Evaluate NixOS modules
  nixosEval = lib.evalModules {
    modules = [
      ../modules/nixos/default.nix
      {
        # Minimal config to allow evaluation
        _module.check = false;
        boot.loader.grub.enable = false;
        fileSystems."/" = { device = "/dev/vda"; fsType = "ext4"; };
        system.stateVersion = "25.11";
      }
    ];
  };

  # Evaluate Home Manager modules
  homeEval = lib.evalModules {
    modules = [
      ../modules/home/default.nix
      { _module.check = false; }
    ];
  };

  # Generate documentation
  nixosOptionsDoc = pkgs.nixosOptionsDoc {
    options = nixosEval.options;
    transformOptions = opt: opt // {
      # Filter to only marchyo.* options
      visible = lib.hasPrefix "marchyo." opt.name;
    };
  };

  homeOptionsDoc = pkgs.nixosOptionsDoc {
    options = homeEval.options;
    transformOptions = opt: opt // {
      visible = lib.hasPrefix "programs." opt.name ||
                lib.hasPrefix "services." opt.name ||
                lib.hasPrefix "home." opt.name;
    };
  };

in {
  nixos = nixosOptionsDoc.optionsCommonMark;
  home = homeOptionsDoc.optionsCommonMark;
  nixosJson = nixosOptionsDoc.optionsJSON;
  homeJson = homeOptionsDoc.optionsJSON;
}
```

#### Integration with mdBook

- Pre-build hook to generate options
- Copy generated markdown to `src/reference/modules/`
- Update SUMMARY.md automatically

### Phase 3: Content Creation (Week 3-4)

#### Tutorials (Learning-Oriented)
1. **Installation Guide**
   - ISO download/build
   - Hardware requirements
   - Partitioning with disko
   - First boot and configuration

2. **First Configuration**
   - Understanding flakes
   - Setting up hardware-configuration.nix
   - Enabling feature flags
   - Building and activating

3. **Adding Modules**
   - Understanding the module system
   - Custom user configuration
   - Adding packages
   - Using home-manager

#### How-To Guides (Problem-Oriented)
1. **Customize Theme**
   - Available color schemes
   - Creating custom schemes
   - Applying to applications

2. **Configure Desktop**
   - Hyprland customization
   - Keybindings
   - Window rules
   - Startup applications

3. **Setup Development Environment**
   - Development tools overview
   - Docker configuration
   - Git setup
   - IDE integration

4. **Troubleshooting**
   - Common errors
   - Boot issues
   - Network problems
   - Rollback procedures

#### Reference (Information-Oriented)
1. **Module Options** (Auto-generated)
   - NixOS options (marchyo.*)
   - Home Manager options
   - Generic options

2. **Feature Flags**
   - Complete reference
   - Dependencies
   - Enabled packages/services

3. **Color Schemes**
   - Available schemes
   - Palette reference
   - Integration guide

4. **Default Applications**
   - List of default apps
   - Customization guide

#### Explanation (Understanding-Oriented)
1. **Architecture**
   - Project structure
   - Module organization
   - Dependency graph

2. **Module System**
   - How modules work
   - Evaluation process
   - Best practices

3. **Theming System**
   - nix-colors integration
   - Color propagation
   - Application theming

4. **Design Decisions**
   - Why Hyprland
   - Feature flag rationale
   - Single-user focus

### Phase 4: Build & Deployment (Week 5)

#### mdBook Configuration

`docs/book.toml`:
```toml
[book]
title = "Marchyo Documentation"
authors = ["Marchyo Contributors"]
description = "Comprehensive documentation for the Marchyo NixOS configuration flake"
language = "en"
multilingual = false
src = "src"

[output.html]
theme = "theme"
default-theme = "ayu"
preferred-dark-theme = "ayu"
git-repository-url = "https://github.com/Jylhis/marchyo"
git-repository-icon = "fa-github"
edit-url-template = "https://github.com/Jylhis/marchyo/edit/main/docs/{path}"

[output.html.search]
enable = true
limit-results = 30
use-boolean-and = true
boost-title = 2
boost-hierarchy = 1
boost-paragraph = 1
expand = true

[output.html.fold]
enable = true
level = 0

[preprocessor.links]

[build]
build-dir = "build"
create-missing = true
```

#### GitHub Actions Workflow

`.github/workflows/docs.yml`:
```yaml
name: Build and Deploy Documentation

on:
  push:
    branches:
      - main
    paths:
      - 'docs/**'
      - 'modules/**'
      - '.github/workflows/docs.yml'
  pull_request:
    paths:
      - 'docs/**'
  workflow_dispatch:

jobs:
  build-docs:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pages: write
      id-token: write
    steps:
      - uses: actions/checkout@v5
      - uses: DeterminateSystems/determinate-nix-action@main
      - uses: DeterminateSystems/magic-nix-cache-action@main

      - name: Build documentation
        run: nix build .#docs

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: result

      - name: Deploy to GitHub Pages
        if: github.ref == 'refs/heads/main'
        uses: actions/deploy-pages@v4
```

#### Offline Documentation Package

Create `packages.marchyo-docs` for offline use:
```nix
pkgs.stdenv.mkDerivation {
  name = "marchyo-docs";
  src = packages.docs;

  installPhase = ''
    mkdir -p $out/share/doc/marchyo
    cp -r * $out/share/doc/marchyo/

    # Create launcher script
    mkdir -p $out/bin
    cat > $out/bin/marchyo-docs << 'EOF'
    #!/bin/sh
    ${pkgs.python3}/bin/python -m http.server 8080 \
      --directory ${placeholder "out"}/share/doc/marchyo
    EOF
    chmod +x $out/bin/marchyo-docs
  '';
}
```

---

## Success Criteria

### Functional Requirements
- ✅ Auto-generated module options documentation
- ✅ Offline browsing capability
- ✅ Full-text search
- ✅ Responsive design (mobile-friendly)
- ✅ Syntax highlighting for Nix code
- ✅ Cross-references between sections
- ✅ Edit on GitHub links

### Content Requirements (Diataxis)
- ✅ **Tutorials**: 3+ step-by-step guides
- ✅ **How-To**: 4+ problem-solving guides
- ✅ **Reference**: Complete auto-generated options
- ✅ **Explanation**: 4+ conceptual documents

### Technical Requirements
- ✅ Build time < 2 minutes
- ✅ Reproducible builds (Nix)
- ✅ CI/CD integration
- ✅ GitHub Pages deployment
- ✅ Offline package for installer

---

## Timeline Summary

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1 | Infrastructure | mdBook setup, flake integration, CI/CD |
| 2 | Auto-generation | Options docs generator, build integration |
| 3-4 | Content | Tutorials, how-tos, reference, explanation |
| 5 | Deployment | GitHub Pages, offline package, polish |

**Total**: 5 weeks

---

## Future Enhancements (Post-V1.0)

1. **Versioned Documentation**
   - Docs for each release
   - Version switcher

2. **Multi-language Support**
   - Internationalization
   - Translation workflow

3. **Interactive Examples**
   - Code playground
   - Try before you configure

4. **API Documentation**
   - `lib.marchyo.*` functions
   - Auto-generated from source

5. **Video Tutorials**
   - Installation walkthrough
   - Configuration guides

6. **Community Contributions**
   - Cookbook section
   - User-submitted configs
   - Tips and tricks

---

## Maintenance Plan

### Keeping Documentation Current

1. **Automated Updates**
   - Options docs regenerate on every build
   - CI validates links
   - Spell checking

2. **Review Process**
   - PRs must update relevant docs
   - Docs review checklist
   - Quarterly documentation audit

3. **User Feedback**
   - GitHub issues for doc improvements
   - "Was this helpful?" on each page
   - Analytics (privacy-respecting)

---

This plan provides a comprehensive, maintainable, and user-friendly documentation system aligned with Marchyo's V1.0 goals.
