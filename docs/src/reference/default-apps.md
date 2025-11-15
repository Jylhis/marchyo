# Default Applications

Applications configured by Marchyo.

## Desktop Applications

When `marchyo.desktop.enable = true`, the following applications are installed and configured:

### Communication

- **Signal Desktop** - Private messaging
  - Keybinding: `Super + G`
  - Variable: `$messenger`

### Web & Productivity

- **Brave Browser** - Privacy-focused web browser
  - Keybinding: `Super + B`
  - Variable: `$browser`
  - Wayland mode enabled

- **Obsidian** - Note-taking application
  - Keybinding: `Super + O`
  - Variable: `$notes`

### File Management

- **Nautilus** - GNOME file manager
  - Keybinding: `Super + F`
  - Variable: `$fileManager`

- **LocalSend** - Local file sharing

### Terminal

- **Kitty** - Fast GPU-accelerated terminal
  - Keybinding: `Super + Return`
  - Variable: `$terminal`

### Security

- **1Password** - Password manager
  - Keybinding: `Super + /`
  - Variable: `$passwordManager`

## Media Applications

When `marchyo.media.enable = true`:

- **Spotify** - Music streaming (requires `allowUnfree = true`)
  - Keybinding: `Super + M`
  - Variable: `$music`

- **MPV** - Lightweight video player

## Office Applications

When `marchyo.office.enable = true`:

- **LibreOffice** - Office suite
- **Papers** - Document manager (GNOME)
- **Xournalpp** - PDF annotation

## Development Applications

When `marchyo.development.enable = true`:

### Container Tools

- **Docker** - Container runtime
- **LazyDocker** - Docker TUI
  - Keybinding: `Super + D`

### Version Control

- **Git** (with LFS) - Version control
- **LazyGit** - Git TUI

### Virtualization

- **virt-manager** - Virtual machine manager
- **virt-viewer** - VM viewer

### Kubernetes

- **k9s** - Kubernetes TUI

## System Utilities

### TUI Tools

- **btop** - System monitor
- **fastfetch** - System info
- **bluetui** - Bluetooth TUI
- **sysz** - Systemd TUI
- **lazyjournal** - Journalctl TUI

### CLI Tools

- **fzf** - Fuzzy finder
- **ripgrep** - Fast search
- **eza** - Modern ls
- **fd** - Modern find
- **bat** - Cat with syntax highlighting
- **sd** - Find and replace
- **duf** - Disk usage
- **gping** - Ping with graph
- **xh** - HTTP client
- **aria2** - Download manager

## Customizing Defaults

### Change Default Terminal

```nix
wayland.windowManager.hyprland.settings = {
  "$terminal" = "alacritty";
};
```

### Change Default Browser

```nix
wayland.windowManager.hyprland.settings = {
  "$browser" = "firefox";
};
```

### Add Custom Application Keybinding

```nix
wayland.windowManager.hyprland.settings = {
  bind = [
    "SUPER, E, exec, emacs"
  ];
};
```

## See Also

- [Configure Desktop](../how-to/configure-desktop.md) - Customize applications
- [Feature Flags](feature-flags.md) - Enable application groups
