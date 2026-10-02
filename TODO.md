# Marchyo shell roadmap

Plan distilled from researching the Quickshell/dotfiles repos below against
marchyo's current shell. Ordered by value. Workstream 1 (fully runtime theming)
is the flagship; the rest are independent and can land in any order.

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
no activation/rebuild. Today the shell, GTK (libadwaita via dconf), and Ghostty
already recolor at runtime; stylix still bakes the rest at build time.

**The stylix question.** Stylix is not theming the surfaces marchyo owns — those
are already disabled in `modules/generic/theme.nix` (hyprland, waybar, mako,
ghostty, gtk, hyprlock, console, bat, fzf, starship, aerc, vicinae). Stylix's
remaining job is the **base16 fallback for the long tail**: Qt/KDE apps, console,
bat, fzf, starship, and non-libadwaita GTK. Stylix cannot be dropped until those
have a runtime path. So this workstream is "build a runtime replacement, then
retire stylix," not "delete stylix."

Steps:

1. **Inventory what stylix still colors.** Confirm the live-themed set (shell,
   libadwaita GTK via dconf, Ghostty via portal) vs. the build-time set
   (Qt/qt5ct/qt6ct, console/TTY, bat, fzf, starship, GTK base16). Write the list
   into this workstream before touching code.
2. **Runtime palette emitter.** Extend the per-theme dir under
   `~/.config/marchyo/current-theme` (already carries `colors.json` + `gtk.css`)
   so `marchyo theme set` also materializes, from one palette source, the config
   each long-tail app reads at startup / on reload:
   - bat: `--theme` / `BAT_THEME` or a generated `.tmTheme`.
   - fzf: `FZF_DEFAULT_OPTS` `--color=...` (re-exported; already env-driven).
   - starship: palette block in `starship.toml`.
   - Qt: qt5ct/qt6ct colorscheme `.conf` (+ `QT_QPA_PLATFORMTHEME`).
   - GTK non-libadwaita: the existing `gtk.css` already relinks; extend to a
     full base16-equivalent token set.
   This is the DMS `paletteinject.go` / template approach, done the marchyo way
   (CLI writes files + signals). Reference: DankMaterialShell `core/internal/matugen/`
   (`seedcache.go`, `paletteinject.go`) and the `dank16/` 16-color terminal palette.
3. **Reload signalling per app.** Prefer native live-reload (portal color-scheme,
   config file-watch, SIGUSR). For apps that only read config at startup,
   document that new instances pick up the swap (acceptable) and note which
   cannot (if any).
4. **Single palette source of truth.** All emitters (shell `colors.json`,
   `gtk.css`, bat/fzf/starship/Qt) derive from one palette definition so dark/light
   and custom schemes stay consistent. Keep the Nix generator in
   `packages/marchyo-shell/package.nix` as the *build-time default* only; runtime
   writes override it.
5. **Retire stylix.** Once the long tail has a runtime path, remove the stylix
   inputs (`flake.nix` `stylix`/`stylix-stable`, `outputs.nix`), delete
   `modules/generic/stylix.nix`, and collapse `modules/generic/theme.nix`
   (its only job was disabling stylix targets). Re-home the font stack
   (Zilla Slab / Hanken Grotesk / BlexMono) and cursor currently set via stylix
   into a marchyo-owned module. Update `tests/eval/themes.nix` and
   `lib/font-scale.nix` comments.
6. **Decide on wallpaper-driven Material-You (optional follow-up).** The runtime
   emitter above makes live palettes possible from *any* source. A matugen-style
   "extract palette from current wallpaper" mode could feed the same emitter.
   Flag as optional; marchyo's identity is the jylhis palette, so this is a mode,
   not the default. Reference: caelestia `Colours` service, end-4 `MaterialThemeLoader.qml`.

**Acceptance:** `marchyo theme set <x>` restyles shell + GTK + Ghostty + Qt +
bat/fzf/starship + console with no rebuild; stylix inputs removed; `just check`
and `just build-nixos`/`build-darwin` green; eval tests updated.

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
| **bat** | build-time | `.tmTheme` + `config.theme` / `BAT_THEME` | next-instance (fresh process each run) | Emit per-theme `.tmTheme` into the theme dir from the palette (16 ANSI + fg/bg/selection), set `BAT_THEME` / point `BAT_CONFIG_PATH` at the theme dir's `bat.conf`. For the Jylhis pair reuse the shipped `pkgs.jylhis-themes` tmThemes; generate a tmTheme for base16/matugen schemes. Fresh process per invocation, so next-instance is effectively live. |
| **fzf** | build-time | `FZF_DEFAULT_OPTS` `--color=` (shell init env) | live if `FZF_DEFAULT_OPTS_FILE` (fzf 0.48+), else next-shell | Emit `fzf.opts` (`--color=...` line) into the theme dir; set `FZF_DEFAULT_OPTS_FILE=$XDG_CONFIG_HOME/marchyo/current-theme/fzf.opts` once in shell init. Every new fzf launch then reads the current theme live. Keep layout opts in `FZF_DEFAULT_OPTS` (merged). |
| **starship** | build-time | `starship.toml` (`STARSHIP_CONFIG`) | next-prompt (`starship prompt` is a fresh process each render) | Emit `starship.toml` into the theme dir with a `palette`/`[palettes.marchyo]` block translated from tokens; point `STARSHIP_CONFIG` at the theme dir copy. Next prompt render (sub-second) picks it up, no shell re-exec. Jylhis base toml comes from `jylhis-design-src`; inject/override the palette block. |
| **Qt (qt5ct/qt6ct)** | build-time (stylix `qt` target) | `qt5ct`/`qt6ct` colorscheme `.conf` (ARGB palette rows) + `QT_QPA_PLATFORMTHEME` | qt5ct/qt6ct: next-instance only (no live signal); gtk3 platform theme: live (follows GTK) | **Decision needed (see below).** Option A: switch session `QT_QPA_PLATFORMTHEME=gtk3` so Qt follows the already-live GTK surface (the shell wrapper already proves this path). Option B: emit a qt5ct/qt6ct colorscheme `.conf` per theme from the palette, relink it, keep `QT_QPA_PLATFORMTHEME=qt5ct` (next-instance only). |
| **hyprlock** | build-time | hyprlang config (`programs.hyprlock.settings`) | next-event (only runs at lock) | Emit a `hyprlock-colors.conf` into the theme dir (bg/text/border/accent/err as `rgba()`), `source` it from the base hyprlock config. Next lock uses current colors. No live signal needed (not running between locks). |
| **console / TTY** | build-time | `console.colors` (kernel palette, `tty16`) | **next-event / privileged** | **Flagged below.** Emit a `setvtrgb`-format table into the theme dir. Live application to active VTs requires `setvtrgb` writing to the console (VT-bound, needs the console device), which a Wayland-session user process cannot do cleanly. Realistically next-boot / next-VT, or a privileged helper. |

**Decisions (step 1, confirmed):**

- **Qt -> Option A (follow GTK).** Set session `QT_QPA_PLATFORMTHEME=gtk3` so Qt
  apps read the already-live GTK surface; this drops the qt5ct/qt6ct dependency
  and gives live Qt restyling for free. Needs the gtk3 platform-theme plugin
  present for Qt5 and Qt6 (`qt5.qtstyleplugins` / `qt6.qt6gtk2` or the
  `qgtk3`/gtk3 platformtheme). No per-theme Qt asset is emitted.
- **Console -> emit + accept next-boot.** Emit a `setvtrgb` table per theme for
  consistency; live VTs apply it on next boot/VT setup. `console.colors` stays
  the declarative default via `modules/nixos/console.nix`. Does not block
  retiring stylix (console is marchyo-owned already).

**Surfaces flagged as not cleanly live-runtime:**

- **console / TTY** is the only genuine holdout. The palette can be *emitted* at
  runtime from the same source, but *applying* it to live VTs needs `setvtrgb`
  (or per-VT `\033]P` escapes) against the console device. From inside the
  Wayland GUI session there is no attached VT to write to, and doing it
  system-wide is privileged. It is also the lowest-value surface for a live swap
  (you are in the GUI, not a TTY). Proposed: still emit the table so it is
  consistent, accept next-boot application, and keep `console.colors` as the
  declarative default (this does not block retiring stylix, since console is
  already in stylix's disabled-targets list and marchyo owns it via
  `modules/nixos/console.nix`).

- **Qt** is not a holdout but needs a design decision (A vs B above) before
  implementing, because A removes the qt5ct dependency entirely and gives live
  theming for free, while B keeps parity with stylix's current output but stays
  next-instance.

**Upstream-dependency note:** all emitters derive from existing palette tokens /
ANSI slots. No missing token identified so far; if the Qt palette needs a role
with no token (e.g. a distinct "button" vs "window" shade) it will be reported
as a `pkgs.jylhis-design-src` gap rather than invented locally.

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

## Notes / constraints

- Verification for marchyo changes stops at `nix build` / `nix flake check` on
  this host; activation/rebuild of the running system is the user's own action.
- Every new module/option needs a `testNixOS` eval test; option declarations stay
  platform-neutral (Darwin eval gate).
- Keep `site/src/content/docs/docs/configuration/` in sync with new options.
- Run `just fmt` + `just check` before each commit; conventional commit messages.
