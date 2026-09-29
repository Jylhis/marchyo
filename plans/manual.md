# Plan: The Marchyo Manual — remaining chapters

The manual (`manual/` at the repo root, symlinked into the Starlight site as
`site/src/content/docs/manual` and covered by the `site.yml` build filter)
follows omarchy's model: a flat, numbered sequence of prose chapters you read
front-to-back, distinct from the option reference. Audience is end users, not
contributors — no Nix internals, no module paths; voice is prose-first,
second-person, task-oriented.

**Status:** 9 of the 14 chapters are written
(01, 02, 04, 06, 07, 08, 09, 10, 11). Five remain TODO stubs:

| # | Chapter | Source to adapt | Notes |
|---|---------|-----------------|-------|
| 03 | Coming from Other Distros | new | Arch/omarchy/mac/win switchers; the golden rule (never install imperatively) |
| 05 | The Top Bar | shell/README.md | **Stale stub**: describes the Waybar tour — the marchyo shell (`marchyo.shell.enable`) is now the default-when-enabled bar; cover both, keyed on the flag |
| 12 | Monitors | `configuration/graphics` + hyprmon | declarative vs TUI, scaling + the scale-cycle bind, lid behavior |
| 13 | Networking | new | wifi/bt TUIs, tailscale default + trusted interface, localsend, firewall default |
| 14 | Hardware Authentication | `configuration/…` | fingerprint (`marchyo.security.fingerprint.enable`), FIDO2, `marchyo security enroll` |

Conventions for filling them in: minimal Starlight frontmatter (`title`,
optional `description`), kebab-case numbered files with gaps allowed,
text-first (screenshots only in a later assets pass). The manual complements
the `usage/`/`configuration/` reference pages; it does not replace them.

Also fold into 05 when written: the bar's click behavior (panels, TUI
launches), tooltips, and `SUPER+SHIFT+SPACE` toggle — see
`shell/README.md` for the current widget set.
