# Marchyo workstation template

A desktop and development workstation built on Marchyo.

## Install

```bash
nix flake init -t github:Jylhis/marchyo#workstation
nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Edit `configuration.nix`: the host name, `marchyo.users.developer` (rename it
and `users.users.developer` to your user name), and `system.stateVersion` if
you installed a different NixOS release. Then build and switch:

```bash
sudo nixos-rebuild switch --flake .#workstation
```

To try it in a VM first:

```bash
nixos-rebuild build-vm --flake .#workstation
./result/bin/run-workstation-vm
```

## What you get

- `marchyo.desktop.enable`: Hyprland, the Marchyo shell, Ghostty, the Jylhis
  theme, office and media apps.
- `marchyo.development.enable`: Git with LFS, GitHub CLI, rootless Podman
  (set `marchyo.development.containers.backend = "docker"` for Docker),
  libvirt/QEMU, direnv with nix-direnv, and build tools.

Pick editors with `marchyo.defaults.editor` and
`marchyo.defaults.terminalEditor`, and describe displays with
`marchyo.monitors`.

## Update

```bash
nix flake update
sudo nixos-rebuild switch --flake .#workstation
```

The [Marchyo manual](https://marchyo.org/docs/) covers everything else.
