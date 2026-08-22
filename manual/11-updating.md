---
title: Updating
description: Keeping your system current, and rolling back when something breaks.
---

Updating Marchyo is ordinary NixOS. There's no special updater and no "update channel"
to babysit. You bump the pinned versions your system is built from, rebuild, and if
you don't like the result, you boot the previous version. Every rebuild saves a
**generation** — a complete, bootable snapshot of your system — so going back is always
an option.

## The short way

The [marchyo CLI](./08-the-marchyo-cli.md) wraps the whole loop into a few words:

```bash
marchyo update      # fetch the latest versions
marchyo upgrade     # fetch the latest, then rebuild onto them
marchyo rollback    # go back to the previous generation
marchyo gc          # clean up old generations you no longer need
marchyo diff        # see what changed between generations
```

For most people, `marchyo upgrade` is the whole story: it updates and rebuilds in one
step.

## The long way

If you'd rather run it by hand, the two steps are: bump the versions, then rebuild.

```bash
# In the directory holding your flake.nix:
nix flake update                # bump everything to the latest
# or just Marchyo:
nix flake update marchyo

sudo nixos-rebuild switch --flake .#yourhost
```

On a Mac it's `darwin-rebuild switch --flake .#yourhost` instead.

:::note
`nix flake update` rewrites `flake.lock`, the file that records exactly what your
system is built from. Commit it after an update — that's what makes the change
reproducible and reviewable, and lets you build the identical system again later.
:::

Marchyo picks the package set for you, so there's no separate `nixpkgs` to manage.
Updating Marchyo is what moves your packages forward. (On most systems that's the
rolling "unstable" set; Intel Macs are pinned to a stable release.)

## Rolling back

If a rebuild misbehaves, undo it:

```bash
sudo nixos-rebuild switch --rollback
```

Or reboot and pick any earlier generation straight from the **boot menu** — each one is
its own entry, so even a system that won't come up gives you a working version to
return to. That's the safety net that makes updating low-stakes: you can always get
back to the last system that worked.

:::note
A rollback restores the **system**, not your files. Your home directory is untouched
by rolling back — generations capture the OS and its packages, not your documents. Use
rollback to undo a broken system change; use your own backups for personal data.
:::

## Cleaning up

Old generations pile up over time and take disk space. `marchyo gc` prunes the old
ones (by default, anything older than two weeks). If you'd rather do it by hand:

```bash
sudo nix-collect-garbage -d
```

That removes old generations and frees the store. Keep at least one known-good
generation around until you're confident the current one is stable.
