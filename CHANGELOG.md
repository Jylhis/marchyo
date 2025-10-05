# Changelog

All notable changes to Marchyo will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive README.md with installation instructions and feature overview
- CONTRIBUTING.md with development guidelines and code style
- CHANGELOG.md for tracking project changes

### Changed
- (Changes will be listed here)

### Fixed
- (Fixes will be listed here)

## [0.1.0] - Initial Development

### Added
- Flake-based NixOS configuration with flake-parts
- Modular architecture (nixos/, home/, generic/ modules)
- Custom `marchyo.*` namespace for options
- Feature flags: desktop, development, media, office
- User configuration with email and fullname metadata
- Home Manager integration as NixOS module

#### NixOS Modules
- Audio: PipeWire configuration
- Boot: systemd-boot with greetd login manager
- Containers: Docker/Podman support
- Fonts: Nerd Fonts, Liberation, Inter
- Graphics: Mesa, Vulkan, hardware acceleration
- Hyprland: Hyprland compositor system configuration
- Locale: Timezone and locale settings
- Media: Media applications (conditional)
- Network: NetworkManager configuration
- Packages: System packages based on feature flags
- Plymouth: Custom Marchyo boot theme
- Printing: CUPS printing support
- Security: Polkit configuration
- Performance: Kernel optimizations
- Power Save: TLP and power management

#### Home Manager Modules
- btop: System resource monitor
- fastfetch: System information display
- Git: Full git configuration with LFS
- Ghostty: Ghostty terminal configuration
- Hypridle: Idle management and auto-lock
- Hyprland: User Hyprland configuration with keybindings
- Hyprlock: Screen lock configuration
- Hyprpaper: Wallpaper management
- Kitty: Kitty terminal configuration
- Mako: Notification daemon
- Shell: Bash/Fish with enhancements
- Waybar: Status bar with modules
- Wofi: Application launcher
- Xournal++: PDF annotation tool
- 1Password: SSH agent integration

#### Developer Tools
- Modern CLI tools: eza, bat, fd, ripgrep, zoxide
- Shell enhancements: starship prompt, Fish/Bash
- Container tools: Docker, Buildah, Skopeo
- GitHub CLI: gh
- Lazy tools: lazygit, lazydocker

#### Custom Packages
- hyprmon: Hyprland monitor configuration TUI
- plymouth-marchyo-theme: Custom Plymouth boot theme

#### Testing Infrastructure
- Comprehensive VM tests for NixOS modules
- Home Manager configuration tests
- Integration tests for feature combinations
- Test documentation in tests/README.md

#### CI/CD
- Cachix binary cache integration
- FlakeHub publishing
- Code quality checks (nixfmt, statix, deadnix)
- Automated testing on push

### Documentation
- CLAUDE.md for AI-assisted development
- Nix-implementer agent for automated changes
- Test README with testing guidelines

---

## Version History Format

Each version should include:
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

[Unreleased]: https://github.com/Jylhis/marchyo/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Jylhis/marchyo/releases/tag/v0.1.0
