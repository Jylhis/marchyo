---
title: Updating
description: The declarative rebuild model — how you change and update a marchyo system.
---

TODO — the chapter that explains marchyo's core difference. Cover:

- the rebuild loop in full: edit config → `nixos-rebuild switch` → generations
- updating inputs (`nix flake update`) and what that bumps
- rollback: how to boot a previous generation when something breaks
- the `marchyo`/`dix` diff surface for "what changed"
- why you never install packages imperatively

Adapt from `site/src/content/docs/docs/usage/updating.mdx`. This is the marchyo
counterpart to omarchy's imperative `omarchy-update`.
