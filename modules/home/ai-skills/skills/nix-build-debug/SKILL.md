---
name: nix-build-debug
description: Diagnose Nix/NixOS build and evaluation failures in the Marchyo flake. Use when a `nix build`, `nixos-rebuild`, or `nix flake check` fails — to read the error trace, locate the offending expression, and propose a fix.
---

# Nix Build Debug Skill

Systematic debugging of Nix evaluation and build failures.

## Triage order

1. **Read the trace bottom-up.** The last `error:` line is the proximate cause;
   the `… while` frames above it show the path that led there.
2. **Classify the failure:**
   - *Evaluation error* (infinite recursion, `attribute missing`, type error,
     assertion) — happens before any build; fix the expression.
   - *Build error* (compiler/test failure, hash mismatch, missing dependency) —
     a derivation failed to realise.
3. **Re-run narrowly:** `nix eval` the failing attr, or
   `nix build .#<attr> --show-trace -L` for full logs.

## Common cases

- **`attribute 'X' missing`** — a typo or an option/package that doesn't exist.
  For nixpkgs attrs, verify the real name (use the mcp-nixos tool if available).
- **`infinite recursion encountered`** — usually a `config` referring to itself,
  or a missing `lib.mkIf`/`mkDefault` causing a cycle. Bisect by commenting blocks.
- **Hash mismatch (`got:` / `specified:`)** — copy the `got:` SRI hash into the
  derivation's `hash`/`cargoHash`/`npmDepsHash`.
- **Assertion failure** — read the message; Marchyo uses assertions for removed
  options and required fields (e.g. `marchyo.ai.openrouter.apiKeyFile`).
- **Darwin eval breakage** — an `options/*.nix` default referenced a Linux-only
  package. Keep option files platform-neutral; put package refs in impl modules.

## Marchyo specifics

- Tests are eval-only (`tests/eval/*.nix` via `testNixOS`/`withTestUser`); a failing
  test is an evaluation error, not a build.
- `just check` runs `nix flake check`; `just fmt` runs treefmt. Both must pass.
- The reference build is `nix build .#nixosConfigurations.x86_64.config.system.build.toplevel`.
