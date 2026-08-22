# Plan: The Marchyo Manual

**Revision 1 — draft.** Initial plan + skeleton for a published end-user manual.

## Problem

Marchyo's user-facing documentation today is spread across the Starlight site's
`configuration/`, `usage/`, and `guides/` sections — organized by *option*, not by
*the person sitting in front of the desktop*. Omarchy solves this with a `manual/`:
a flat, numbered sequence of prose chapters you read front-to-back to learn the
system, distinct from the reference docs. Marchyo wants the same: a cohesive,
second-person manual that teaches the desktop, separate from the option tables.

This mirrors the three-tree documentation split now in place:

- **`docs/`** — contributor/system-architecture reference (how marchyo is *built*).
- **`manual/`** — this: published end-user chapters (how to *use* marchyo).
- **`plans/`** — design RFCs (what we're *building next*).

## Audience & voice

- **Audience:** end users of a marchyo desktop, not contributors. No Nix internals,
  no module paths, no flake-output tables — those live in `docs/` and the site
  `configuration/` reference.
- **Voice:** prose-first, second person ("you"), conversational, task-oriented.
  Follow omarchy's manual tone. Screenshots welcome later; text first.
- **Marchyo-specific framing** (differs from omarchy, call these out per chapter):
  - The system is **declarative** — you change it by editing your Nix config and
    rebuilding (`nixos-rebuild switch`), not by mutating a running system. The
    manual teaches the *desktop experience*; the *how-to-change-it* is the rebuild
    model, covered in "Updating".
  - The **`marchyo` CLI** is the omarchy-parity command surface (menus, toggles,
    capture, theme). Frozen contract until 2.0.
  - **BYOK AI**, **multi-platform** (NixOS + darwin + nix-on-droid) are marchyo
    extras with no omarchy equivalent.

## Format & location

- **Location:** top-level `manual/` at the repo root — the authoritative source.
- **Files:** flat, numbered, kebab-case: `01-welcome-to-marchyo.md`, … Sparse
  numbering (gaps allowed) so chapters can be inserted without renumbering.
- **Frontmatter:** each chapter carries minimal Starlight frontmatter (`title`,
  optional `description`). This is the one concession to the renderer — the files
  are otherwise plain markdown. (Omarchy's have no frontmatter because it renders
  via a different mirror; marchyo renders through Starlight, which requires a
  `title`.)

## Rendering (Starlight wiring — the one non-mechanical decision)

Starlight's `docsLoader()` only globs `site/src/content/docs/`. A repo-root
`manual/` is not auto-seen. Options considered:

1. **Symlink** `site/src/content/docs/manual → ../../../../manual`, add a "Manual"
   sidebar group (`autogenerate: { directory: 'manual' }`). Keeps `manual/`
   authoritative at root; the symlink follows on Linux CI and the Cloudflare
   Workers build. **← chosen** (simplest that keeps root authority).
2. Second Astro content collection with a custom `glob` loader based at `../manual`
   — Starlight's sidebar only renders the `docs` collection, so this doesn't
   integrate cleanly.
3. Author inside the site and sync root `manual/` at build — duplicates content.

**Chosen: option 1.** Also add `manual/**` to the `paths:` filter in
`.github/workflows/site.yml` so root-level manual edits trigger the site build
gate (the filter currently watches only `site/**`).

If the symlink ever proves fragile in the build, fall back to a prebuild copy step
in `site/package.json` (`cp -r ../manual src/content/docs/manual`) guarded by
`.gitignore` — same routes, no symlink.

## Chapter outline (initial)

Adapted from omarchy's 37 chapters, trimmed to a marchyo-shaped starter set.
Reuse/adapt existing site prose where noted.

| # | Chapter | Source to adapt | marchyo-specific notes |
|---|---------|-----------------|------------------------|
| 01 | Welcome to Marchyo | new | philosophy: a declarative omarchy |
| 02 | Getting Started | `docs/quickstart` | first boot, the rebuild loop |
| 03 | Coming from Other Distros | new | for Arch/omarchy/mac/win switchers |
| 04 | Navigation | `usage/hotkeys` | workspaces, windows, tiling |
| 05 | The Top Bar | new | waybar segments + click behavior |
| 06 | Themes | `configuration/theming` | dark/light variant, runtime `marchyo theme` |
| 07 | Hotkeys | `usage/hotkeys` | the full bind list (largest chapter) |
| 08 | The Marchyo CLI | `usage/cli` | `marchyo` subcommands |
| 09 | Default Apps | `configuration/default-apps` | browser/editor/terminal choices |
| 10 | AI | `configuration/ai` | BYOK OpenRouter desktop |
| 11 | Updating | `usage/updating` | the declarative rebuild/flake model |
| 12 | Troubleshooting | `usage/troubleshooting` | — |
| 13 | Monitors | `configuration/graphics` + hyprmon | runtime monitor controls |
| 14 | Networking | new | wifi/bluetooth/tailscale/localsend |
| 15 | Hardware Authentication | `configuration/…` | fingerprint / FIDO2 |

## Non-goals (this revision)

- No screenshots yet (text-first; add an assets pass later).
- No mirror to a separate marketing site — the Starlight render at marchyo.org is
  the published surface.
- Not a migration of the existing `usage/`/`configuration/` reference pages; the
  manual *complements* them (narrative) rather than replacing them (reference).

## Status

Skeleton chapters (frontmatter + TODO stubs) land with this plan so the structure,
routes, and sidebar exist. Filling in prose is incremental, chapter by chapter.
