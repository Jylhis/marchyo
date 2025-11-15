# Design Decisions

Rationale behind Marchyo's architecture and choices.

## Core Philosophy

### Keyboard-Driven Workflow

**Decision**: Focus on keyboard-driven interfaces and TUI applications.

**Rationale**:
- Faster navigation once learned
- Less context switching (hands stay on keyboard)
- Better for remote/headless usage
- Accessibility through keyboard shortcuts
- Resource efficient (TUI apps use less memory)

**Implementation**:
- Hyprland with comprehensive keybindings
- TUI tools: btop, lazygit, lazydocker, k9s
- Vicinae launcher for quick access
- Descriptive keybinding system using `bindd`

### Single-User Optimization

**Decision**: Optimize for single-user workstations, not multi-user servers.

**Rationale**:
- Simpler configuration
- Unified system and user settings
- Less permission complexity
- Personal customization focus

**Implementation**:
- Direct `marchyo.users.<name>` configuration
- Home Manager tightly integrated
- User-specific defaults system-wide
- Can still support multiple users if needed

### Feature Flags Over Granular Control

**Decision**: Use high-level feature flags instead of requiring users to enable each package/service individually.

**Rationale**:
- Faster initial setup
- Curated, tested configurations
- Reduced decision fatigue
- Easier to get started
- Still overridable for advanced users

**Implementation**:
```nix
marchyo.desktop.enable = true;  # Enables ~20 related things
# Instead of:
# programs.hyprland.enable = true;
# services.pipewire.enable = true;
# fonts.packages = [ ... ];
# ... 17 more lines
```

## Technology Choices

### Hyprland Window Manager

**Decision**: Use Hyprland as the default window manager.

**Alternatives Considered**: Sway, i3, awesome, qtile

**Rationale**:
- Modern Wayland compositor
- Excellent performance
- Smooth animations
- Active development
- Good NixOS integration
- Keyboard-focused
- Highly customizable

### Kitty Terminal

**Decision**: Kitty as default terminal emulator.

**Alternatives Considered**: Alacritty, wezterm, foot

**Rationale**:
- GPU acceleration
- Good Unicode support
- Ligatures support
- Extensive configuration
- Image display (useful for dev work)
- Active development

### Nix-Colors for Theming

**Decision**: Integrate nix-colors for system-wide theming.

**Alternatives Considered**: Custom theming, manual configuration

**Rationale**:
- 200+ pre-made schemes
- Base16 standard (widely adopted)
- NixOS-native integration
- Easy to switch themes
- Community-maintained
- Consistent color system

### mdBook for Documentation

**Decision**: Use mdBook for documentation generation.

**Alternatives Considered**: Sphinx, DocBook, MkDocs

**Rationale**:
- Fast builds
- Clean, modern output
- Good offline support
- Markdown-based (easy to write)
- Rust ecosystem (aligns with Nix usage)
- Search functionality built-in
- Nix integration via nix-mdbook

## Module Organization

### Three-Tier Module System

**Decision**: Separate modules into nixos/, home/, generic/.

**Rationale**:
- Clear separation of concerns
- System vs user configuration explicit
- Shared modules avoid duplication
- Easier to understand and maintain

### Automatic Module Imports

**Decision**: Automatically import all modules in directories.

**Rationale**:
- Less boilerplate
- Easier to add new modules
- Consistent with Home Manager patterns
- Reduces errors from forgotten imports

**Trade-off**: Less explicit, but convention is clear (all .nix files in modules/).

## Configuration Patterns

### mkDefault for Auto-Configuration

**Decision**: Use `lib.mkDefault` for feature flag side effects.

**Example**:
```nix
config = lib.mkIf cfg.desktop.enable {
  marchyo.office.enable = lib.mkDefault true;  # Can override
};
```

**Rationale**:
- Sensible defaults
- User can override: `marchyo.office.enable = false;`
- Better than forcing with `mkForce`
- Explicit about what's enabled

### Cross-Module Communication via osConfig

**Decision**: Home Manager modules access NixOS config via `osConfig`.

**Example**:
```nix
programs.git.userName = osConfig.marchyo.users.${config.home.username}.fullname;
```

**Rationale**:
- Single source of truth (user info in NixOS config)
- Automatic propagation to user apps
- No duplicate configuration
- Type-safe

## Package Philosophy

### Curated Default Packages

**Decision**: Include opinionated default packages.

**Rationale**:
- Quick start for new users
- Tested combinations
- Modern alternatives to traditional tools (eza vs ls, ripgrep vs grep)
- Can always be removed/replaced

**Default Tool Choices**:
- `eza` over `ls` - Better colors, git integration
- `ripgrep` over `grep` - Faster, better defaults
- `bat` over `cat` - Syntax highlighting
- `fd` over `find` - Simpler syntax
- `btop` over `htop` - Better UI, more features

### Unfree Package Handling

**Decision**: Don't force unfree, document what requires it.

**Rationale**:
- User choice and license awareness
- Clear documentation (Spotify requires unfree)
- Easy to enable: `nixpkgs.config.allowUnfree = true;`
- Respects free software principles

## Testing Strategy

### Lightweight + VM Tests

**Decision**: Two-tier testing (fast evaluation tests + slow VM tests).

**Rationale**:
- Fast feedback for most changes (<1 min)
- Deep validation when needed (VM tests)
- CI efficiency (only run lightweight)
- Optional VM tests for releases

### Auto-Generated Options Docs

**Decision**: Generate module options from source code.

**Rationale**:
- Always up-to-date
- No manual maintenance
- Comprehensive coverage
- Integration with mdBook

## Future-Proofing

### Flakes-First Approach

**Decision**: Use flakes exclusively, no legacy Nix support.

**Rationale**:
- Reproducible builds
- Explicit dependencies
- Better composition
- Future of Nix
- Simpler mental model (no channels)

### x86_64-linux Only (For Now)

**Decision**: Support only x86_64-linux initially.

**Future**: Will add aarch64-linux, aarch64-darwin

**Rationale**:
- Focus on core functionality first
- Most common platform
- Easier to test
- Multi-platform later (less code duplication)

## What We Didn't Do (And Why)

### No Custom Installer TUI

**Decision**: Use standard NixOS installer with documentation.

**Rationale**:
- Installer TUI is complex
- Good documentation sufficient
- Disko configurations provided
- Can add later if needed

### No Custom NixOS Derivation

**Decision**: Library flake, not complete NixOS fork.

**Rationale**:
- Easier to maintain
- Users stay on upstream NixOS
- Better compatibility
- Modules can be used selectively

### No Container Preference (Docker vs Podman)

**Decision**: Install Docker by default but support both.

**Rationale**:
- Docker more common
- Podman easy to switch to
- Both supported by NixOS
- User choice preserved

## Trade-offs

### Opinionated vs Flexible

**Chosen**: Opinionated defaults with override capability

**Trade-off**:
- New users: Quick start (+)
- Advanced users: May need to override (-)
- Mitigation: Everything overridable

### Comprehensive vs Minimal

**Chosen**: Comprehensive feature flags

**Trade-off**:
- Beginner-friendly (+)
- Larger closure size (-)
- Mitigation: Flags are optional, can disable

### Automation vs Explicitness

**Chosen**: Auto-enable related features

**Trade-off**:
- Less configuration needed (+)
- Less obvious what's enabled (-)
- Mitigation: Documentation, `mkDefault` allows override

## Lessons Learned

1. **Feature flags are loved**: Users appreciate high-level configuration
2. **Theming is complex**: Base16 helps but needs good docs
3. **Tests matter**: Lightweight tests catch 90% of issues
4. **Documentation crucial**: Good docs reduce support burden

## See Also

- [Architecture](architecture.md) - System structure
- [Module System](module-system.md) - How modules work
- [Theming System](theming-system.md) - Color integration
