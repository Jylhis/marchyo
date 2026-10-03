# Marchyo shell roadmap

Plan distilled from researching the Quickshell/dotfiles repos below against
marchyo's current shell. Ordered by value. Workstream 1 (fully runtime theming)
is the flagship and is **complete** (stylix retired in 8ff3a33); the rest are
independent and can land in any order.

Explicitly **out of scope**: dashboard panel and calendar panel. Not wanted.

## Source repos (what each is good for)

- https://github.com/AvengeMedia/DankMaterialShell — most mature architecture: IPC CLI, plugin system + lockfile, matugen theming with system-wide injection, control center. Primary reference.
- https://github.com/caelestia-dots/shell — cleanest QML design system: launcher-as-command-palette, JSON config + per-monitor overrides, bar hover popouts.
- https://github.com/ilyamiro/serpantinum — closest Nix-packaged sibling: typed `nix/` options module, CLI-as-IPC, bar "faces" (top/side variants).
- https://github.com/end-4/dots-hyprland (`ii/` Quickshell tree only; AGS is deprecated) — widest feature set: window overview, declarative quick-toggle models, vendored fuzzy-search JS, cliphist image previews.
- https://github.com/Darkkal44/qylock — lock-screen reference (`WlSessionLock` + `PamContext`, failed-attempt UX). Skip its SDDM shim.
- https://github.com/flickowoa/dotfiles/tree/hyprland-yorha — compositor-level effects (per-namespace blur, shell-owned chrome, screen shader).
- https://github.com/diinki/linux-retroism, https://github.com/Nytril-ark/rumda — readable reference QML (fuzzy launcher, theme-switch popup, radial/heatmap widgets).

---

## Workstream 1 — Fully runtime theming (flagship)

**Goal:** a theme swap (`marchyo theme set/next`) restyles *everything* live, with
no activation/rebuild. **Complete:** every per-theme surface has a runtime path
(stylix retired in 8ff3a33); the build-time remainder is by structure (greeter,
plymouth) or by format (TUI long tail keyed on the build-time variant/scheme).

**The stylix question. RESOLVED.** Stylix is gone (8ff3a33): every surface it
still covered when this workstream started (Qt, GNOME interface fonts, cursor,
emacs, the TUI long tail) got a marchyo-owned path first (97d74c5, e01468a).

Steps:

1. **Inventory what stylix still colors. DONE** — the surface matrix below,
   plus the pre-deletion enumeration recorded under "Step 5" below.
2. **Runtime palette emitter. DONE for every per-theme surface** (bat, fzf,
   hyprlock, console; starship needed nothing; Qt follows GTK). The remaining
   long-tail TUIs (lazygit/k9s/ncspot/spotify-player/gdu) are build-time from
   base16 slots (`modules/generic/theme-slots.nix`); making them runtime
   emitters is a possible future extension, not a gap.
3. **Reload signalling per app. DONE** (native live-reload where it exists;
   next-instance documented for the rest).
4. **Single palette source of truth. DONE** — `jylhis-palette.nix` /
   `base16-scheme.nix` feed every emitter; `theme-slots.nix` covers the slot
   consumers.
5. **Retire stylix. DONE (8ff3a33).**
6. **Decide on wallpaper-driven Material-You (optional follow-up). OPEN.** The
   runtime emitter makes live palettes possible from *any* source; matugen
   already covers generate-from-wallpaper for the runtime subset. marchyo's
   identity is the jylhis palette, so this stays a mode, not the default.

**Acceptance (met):** `marchyo theme set <x>` restyles shell + GTK + Ghostty +
Qt + bat/fzf/starship + console with no rebuild; stylix inputs removed; `just
check` and the reference builds' eval gates green (the reference nixos *build*
was blocked during landing by an unrelated, pre-existing vicinae-0.29.1 link
failure — libnumen wants GLIBCXX_3.4.36; reproduced on HEAD without these
changes).

### Step 1 inventory (surface matrix)

Grounded in a full read of `theme-runtime.nix`, the per-app home modules, and
the CLI (`activateThemeDir`, `matugen.ts`). Single palette source is
`modules/generic/jylhis-palette.nix` (`.hex` semantic tokens, `.ansi16`,
`.tty16`) for the Jylhis pair, base16 `scheme.slots` for catalog/inline/matugen
themes. Every new emitter must materialize from that same source in all three
places that build a theme dir: `theme-runtime.nix` (Jylhis pair), its
`mkSchemeThemeDir` (catalog/inline), and the CLI `generateThemeChangeBase`
(matugen), and the reload/relink leg goes in `activateThemeDir`.

Legend: **live** = running processes restyle without relaunch; **next-instance**
= newly launched processes pick it up (a fresh process per use, so effectively
live for that app); **next-event** = applies at the next natural occurrence
(lock, VT switch, boot).

| Surface | State today | Config format it reads | Reload behavior | Runtime emission plan |
|---|---|---|---|---|
| Quickshell shell | runtime | `colors.json` (camelCase tokens) | live (FileView poll -> Color.qml) | done |
| GTK (libadwaita) | runtime | `gtk-3.0/gtk.css` + dconf `color-scheme` | libadwaita live via dconf; GTK3 next-instance | done |
| Ghostty | runtime | `ghostty.conf` theme pair + XDG portal | live (portal color-scheme) | done |
| mako | runtime | `mako/config` | live (symlink + `makoctl reload`) | done |
| waybar | runtime | `waybar/style.css` | live (symlink + `systemctl --user try-restart`) | done |
| Hyprland colors | runtime | `section:subkey value` keywords | live (`hyprctl eval hl.config`) | done |
| Wallpaper | runtime | image file | live (`awww img`) | done |
| **greetd greeter** | build-time (by structure) | `greeter/Commons/Theme.qml` static fallback + package variant-swap generator | next-boot (greeter runs before any user session) | **None needed.** No user session exists under greetd: no current-theme pointer, no marchyo CLI, no dconf — so the greeter is build-time **by structure**, not by omission (pipeline.md "Session-less surfaces"). The variant arrives through `packages/marchyo-shell/package.nix`'s `themeQmlFor ../../greeter/Commons/Theme.qml` generator. Runtime follow-the-session would need the CLI to write a world-readable theme marker the greeter reads at start; flag as optional polish, not a gap. Cozytile (github.com/Darkkal44/Cozytile) proves the demand for greeter-follows-theme (their sudoers-tee SDDM hack) without the declarative machinery. |
| **bat** | **runtime (done)** | `.tmTheme` + `bat.conf` relink (`--theme=` line) | next-instance (fresh process each run) | Shipped in f045fce. The Jylhis pair reuses the shipped `pkgs.jylhis-themes` tmThemes; base16 schemes generate one (`lib/base16-tmtheme.nix`, registered via `programs.bat.themes`). `~/.config/bat/config` relinks to the theme dir's `bat.conf`. Generated (matugen) themes skip bat (shell-subset palette). |
| **fzf** | **runtime (done)** | `fzf.opts` (`--color=` line) via `FZF_DEFAULT_OPTS_FILE` | next-invocation (file read live at every launch) | Shipped. Every theme dir (Jylhis pair, base16 schemes, matugen) emits `fzf.opts`; `FZF_DEFAULT_OPTS_FILE` points at `current-theme/fzf.opts` (read before `FZF_DEFAULT_OPTS`, so the file wins over layout opts). `modules/home/fzf.nix` drops its build-time `programs.fzf.colors` on desktop so the file wins; darwin/non-desktop keep baked colours. Cannot restyle an already-open fzf instance. |
| **starship** | **already runtime** (verified) | `starship.toml` using ANSI slot names, no hex | live (follows the terminal's ANSI palette) | No emitter needed. The design `starship.toml` (`jylhis-design-src/platforms/shell/starship.toml`) has zero hardcoded hexes and styles via ANSI names, which the terminal resolves; Ghostty already swaps its 16-entry ANSI palette live for the Jylhis pair and base16 schemes, so the prompt recolors with it. Doc note landed with the stylix retirement (theming.mdx). |
| **Qt (qt5ct/qt6ct)** | **runtime (done)** | `QT_QPA_PLATFORMTHEME=gtk3` (session-wide, `modules/home/qt.nix`); no qt5ct/qt6ct involved | next-instance (follows the gtk.css relink + dconf color-scheme) | Shipped in e01468a (Option A). Both nixpkgs qtbase generations ship the gtk3 platform-theme plugin (`libqgtk3.so`), so no extra package. The stylix `qt` target is opted out; the shell wrapper pins the same value for the shell process. |
| **TUI long tail (lazygit/k9s/ncspot/spotify-player/gdu)** | build-time (by format) | per-app config from base16 slots (`modules/generic/theme-slots.nix`) | next-instance (config read at launch) | Re-homed from stylix in 97d74c5 with the exact slot mappings stylix used. Not runtime (theme swap does not rewrite them); they follow the build-time `variant`/`scheme`. |
| **Emacs** | build-time | jylhis themes from the design system (`jylhis-design/nix/emacs.nix`) + scaled default font | next-instance | Re-homed from stylix in 97d74c5: loads `jylhis-<variant>` instead of base16-stylix. |
| **GNOME interface fonts + cursor** | n/a (not per-theme) | dconf font-name/document/monospace + `home.pointerCursor` (`modules/home/jylhis-theme.nix`) | n/a | Re-homed from stylix in 97d74c5 (formula mirrors stylix's gnome target; document = applications − 1). |
| **hyprlock** | **runtime (done)** | `hyprlock-colors.conf` sourced into `programs.hyprlock.settings` | next-event (only runs at lock) | Shipped in a797211. Each theme dir emits `hyprlock-colors.conf` as hyprlang `$bg`/`$text`/`$borderStrong`/`$surface`/`$accent`/`$statusErr` vars; `hyprlock.nix` sources it first (sourceFirst) through the current-theme pointer and references the vars. Geometry/fontScale stay build-time. Next lock uses the current theme; no reload signal needed. |
| **console / TTY** | **runtime (done, best-effort)** | `console.txt` (setvtrgb table); `console.colors` declarative default | best-effort live, else next-boot | Shipped. Each theme dir emits a `setvtrgb` table (`console.txt`) from `tty16` (Jylhis) / base16 slots (schemes) via `lib/console-table.nix`. `activateThemeDir` runs `setvtrgb` best-effort (tolerant, like every other actuation); from a Wayland session that usually no-ops and the TTY tracks the declarative `console.colors` (`modules/nixos/console.nix`) at next boot. No privileged helper added (per step-1 decision). |

**Decisions (step 1, confirmed):**

- **Qt -> Option A (follow GTK). SHIPPED (e01468a).** Session-wide
  `QT_QPA_PLATFORMTHEME=gtk3` (`modules/home/qt.nix`); both nixpkgs qtbase
  generations ship the `libqgtk3` platform-theme plugin, so the
  qt5/qt6 plugin packages the decision speculated about were not needed. No
  per-theme Qt asset is emitted.
- **Console -> emit + accept next-boot. SHIPPED (38898a8).** Each theme dir
  emits a `setvtrgb` table; `console.colors` stays the declarative default via
  `modules/nixos/console.nix`.

**Surfaces flagged as not cleanly live-runtime:**

- **console / TTY** is the only genuine holdout. The palette can be *emitted* at
  runtime from the same source, but *applying* it to live VTs needs `setvtrgb`
  (or per-VT `\033]P` escapes) against the console device. From inside the
  Wayland GUI session there is no attached VT to write to, and doing it
  system-wide is privileged. It is also the lowest-value surface for a live swap
  (you are in the GUI, not a TTY). Resolution: the table is emitted per theme,
  next-boot application is accepted, and `console.colors` stays the declarative
  default via `modules/nixos/console.nix`.

- **Qt** shipped as Option A (see the matrix); no residual decision.

**Upstream-dependency note:** all emitters derive from existing palette tokens /
ANSI slots. No missing token identified so far; if the Qt palette needs a role
with no token (e.g. a distinct "button" vs "window" shade) it will be reported
as a `pkgs.jylhis-design-src` gap rather than invented locally.

**Step 5 (retire stylix): SHIPPED** (97d74c5 re-homed the long tail + fonts +
cursor; 8ff3a33 removed the stylix/stylix-stable inputs, deleted
`modules/generic/{stylix,theme}.nix`, pruned flake.lock, and swept the docs).
The enumeration before deletion found stylix's effective coverage was: cursor,
GNOME interface fonts, emacs font+theme, lazygit/k9s/ncspot/spotify-player/gdu
themes — all re-homed. Its fish output was dead (marchyo runs bash) and btop's
theme file was never referenced; everything else targeted apps not installed.
Remaining open in this workstream: step 6 (optional wallpaper-driven
Material-You mode) and the F1/F2/F4 correctness findings recorded in
[`THEME-RUNTIME-REVIEW.md`](THEME-RUNTIME-REVIEW.md) §2.

---

## Workstream 2 — Unified Control Center panel

**Goal:** one quick-settings surface composing services marchyo already has
(Network, Bluetooth, DND, Nightlight, Caffeine/idle-inhibit, ScreenRecording,
PowerProfile, Tailscale, Audio/Mic).

Steps:

1. New `shell/Panels/ControlCenter.qml` (or a dedicated dir) summoned from a bar
   button and via IPC (`marchyo-shell ipc call shell controlCenter`).
2. **Declarative toggle model per capability** — separate toggle logic from
   presentation. Reference: end-4 `modules/common/models/quickToggles/*.qml`
   (`Bluetooth`, `NightLight`, `IdleInhibitor`, `Mic`, `Network`, `PowerProfiles`…).
3. Tile grid + detail pages (a tile opens a detail pane for its domain). Reference:
   DMS `quickshell/Modules/ControlCenter/` (`Components/CcTileGrid.qml`,
   `Widgets/Cc*Tile.qml`, `Details/*Detail.qml`).
4. Reuse existing `Services/*` singletons as the backends — no new daemons.

**Acceptance:** toggles reflect and drive live state; opens/closes via bar + IPC;
each `testNixOS` option that gates a tile has an eval test.

---

## Workstream 3 — Launcher as a command palette

**Goal:** extend the existing apps/clipboard/emoji launcher with pluggable providers.

Steps:

1. Provider pattern: each result source is its own component. Reference:
   caelestia `modules/launcher/services/` (`Apps`, `Actions`, `Schemes`, `M3Variants`).
2. Add providers: calculator (qalc), **theme/scheme switch** (`>theme`), window
   search, power actions. Prefix-routed like caelestia's `>scheme`/`>variant`.
3. Lift the vendored fuzzy-search JS directly — identical in end-4
   (`modules/common/functions/Fuzzy.qml` + `fuzzysort.js`) and retroism
   (`utils/fuzzysort.js` + `Fuzzy.qml`). Avoid writing our own matcher.

**Acceptance:** prefix providers work; clipboard/emoji/apps unaffected; fuzzy
ranking in use.

---

## Workstream 4 — IPC/CLI surface hardening

**Goal:** Hyprland keybinds and scripts drive every panel/action through one CLI,
never touching QML internals. marchyo already has `marchyo-shell ipc call shell lock`;
generalize it.

Steps:

1. One IPC verb per domain: `toggle controlCenter|launcher|<panel>`, `theme next|set`,
   `brightness`, `volume`, `screenshot`, `lock`, `reload`. Reference: DMS
   `core/cmd/dms/` (one `commands_*.go` per domain) and serpantinum
   `serpantinum msg toggle <panel>`.
2. Add a **`marchyo doctor`** health/dependency check (verify tool paths, socket,
   services). Reference: DMS `commands_doctor.go`. Fits marchyo-cli's test culture.
3. Point Hyprland binds (`modules/home/hyprland.nix`, `omarchy-binds.nix`) at the
   CLI verbs.

**Acceptance:** every panel toggles from the CLI; `marchyo doctor` reports PASS/FAIL
per dependency; `just cli-test` green.

---

## Workstream 5 — Config schema + per-monitor overrides

**Goal:** typed, per-monitor shell config. Lower priority — marchyo bakes config via
Nix today; this adds runtime/per-output flexibility.

Steps:

1. Typed options module as the schema source. Reference: serpantinum
   `nix/settings-options.nix` + `hm-module.nix`.
2. Per-monitor overrides with an "ignored options" list (things that must stay
   global, e.g. animations). Reference: caelestia `~/.config/caelestia/monitors/<name>/shell.json`.
3. Keep Nix as the generator of defaults; file-watch for live changes
   (`Commons/Theme.qml` already uses FileView + poll — reuse the pattern).

**Acceptance:** per-monitor bar/position overrides apply live; documented in
`site/src/content/docs/docs/configuration/`.

---

## Workstream 6 — Standalone feature widgets (independent, pick off as desired)

Each is roughly one `Services/` singleton or one widget.

- **Window overview / exposé** with live previews + search. Reference: end-4
  `modules/ii/overview/` (`OverviewWindow.qml`, `SearchWidget.qml`).
- **Lock-screen polish** on the existing `shell/Lock/LockScreen.qml`: failed-attempt
  UX (shake, "ACCESS DENIED", clear field, 3s auto-reset) and input-absorption
  hardening (`PinchHandler`/`WheelHandler`/catch-all `MouseArea`). Reference:
  qylock `themes/material-you-dark/Main.qml` + `lock_shell.qml`. Skip the SDDM shim.
- **Privacy indicator** (active mic/cam in use) as a bar widget. Reference: DMS
  `Widgets/PrivacyIndicator.qml`.
- **Clipboard image previews** in the existing ClipboardView. Reference: end-4
  `CliphistImage.qml` / `services/Cliphist.qml`.
- **Idle-inhibit-on-video**: a singleton watching playerctl/PipeWire that drives
  the existing Caffeine service. (Axarva idea; reimplement natively.)
- **Plugin system evolution**: typed plugin kinds (widget/launcher/daemon) +
  `plugin.json` manifest + lockfile, built on existing `Commons/PluginIndex.qml`
  / `Services/PluginPopout.qml`. Reference: DMS `Services/PluginService.qml`,
  `plugins.lock.json`, `.agents/skills/dms-plugin-dev/`.

---

## Workstream 7 — Compositor-level effects (Hyprland config only, no shell code)

Drop-in to `modules/home/hyprland.nix`, framework-agnostic. Reference:
flickowoa yorha branch.

- Per-namespace layer blur: `layerrule = blur on, match:namespace <bar|...>` so blur
  sits only behind shell surfaces.
- Shell-owned chrome: `border_size = 0` + transparent `col.active_border`, let QML
  draw frames. Fits marchyo's "QML owns the look" model.
- Snappy `popin` bezier for window open; optional CRT/scanline `screen_shader`
  (`gridlines.frag`) if a retro theme is ever wanted.

---

## Workstream 8 — Segmented bar aesthetic (optional, visual only)

**Goal:** an alternative bar look: alternating two-tone segments joined by
curved transitions, instead of the current flat monochrome bar background.
Reference: Cozytile (github.com/Darkkal44/Cozytile) `.config/qtile/config.py`
bar — alternating `#282738`/`#353446` segments with 500x500 PNG separator
images between them (Assets/1-6.png). The look, done the marchyo way:

- Pure QML, zero image assets: each bar section is a `Rectangle` whose left
  and right edges carry concave/convex `Shape` arcs (QtQuick.Shapes) or, for
  the flat variant, simply `radius` — no committed ONGs, no per-theme image
  regeneration. Cozytile ships one PNG set per theme; we derive from
  `Color.qml` tokens at render time.
- Tokens, not hexes: segment fills come from existing semantic tokens
  (`bg`, `surface`, `bgSubtle`) so runtime theme swaps recolor segments live
  through the existing `colors.json` → `Color.qml` path — no new tokens, no
  upstream dependency.
- One place: the segment chrome lives in `shell/Ui/BarSection.qml` (the file
  that already owns per-slot Loaders and separator collapse), as an optional
  presentation mode — the bar stays one `RowLayout` of sections, only the
  background rendering changes. Per-monitor `Bar/` widgets stay untouched.
- Scope guard: this is an aesthetic option on the existing bar, not a
  redesign — no widget-set, layout, or `BarLayout.js` changes; if it grows
  beyond a presentation flag it belongs in a separate workstream.
- No license risk: Cozytile has no LICENSE file; nothing is vendored — only
  the visual idea (alternating two-tone segments with curved joins) is
  borrowed, implemented from scratch against our tokens.

**Acceptance:** `marchyo.bar.segmented = true` (or a Style knob) renders
two-tone curved segments driven by the live palette; `just check` green;
offscreen harness still asserts render state; no new image assets committed.

---

## Notes / constraints

- Verification for marchyo changes stops at `nix build` / `nix flake check` on
  this host; activation/rebuild of the running system is the user's own action.
- Every new module/option needs a `testNixOS` eval test; option declarations stay
  platform-neutral (Darwin eval gate).
- Keep `site/src/content/docs/docs/configuration/` in sync with new options.
- Run `just fmt` + `just check` before each commit; conventional commit messages.
