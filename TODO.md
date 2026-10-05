# Marchyo TODO

Open work only: delete an item in the commit that finishes it. The
authoritative description of the shell is [`shell/README.md`](shell/README.md).

Out of scope, not wanted: a dashboard panel and a calendar panel.

Next up: Control Center (2). New panels get a `marchyo shell` verb, a bind
and `doctor` coverage on arrival.

## 1. Theming

- **Base16 role approximations are lossy for tinted schemes.** `tokenSlots`
  collapses `accent-hover` onto `accent`, `border`/`syn-comment` onto
  `text-faint`, `accent-subtle` onto `bg-subtle`, so a scheme loses the hover
  delta and a future surface putting text on `accent-subtle` would fail
  contrast. Cosmetic; a real fix needs distinct hover/subtle/border roles
  upstream in `jylhis-design`. `tokenSlots` lives in `lib/theme-generators.nix` and
  reaches the CLI through each theme dir's `palette.json`.
- **Optional: wallpaper-driven Material-You mode.** matugen already covers the
  runtime subset; would be a mode, never the default (marchyo's identity is
  the jylhis palette).
- **Optional polish:** greeter follows the session theme (needs a
  world-readable theme marker the greeter reads at start); runtime emitters
  for the TUI long tail (lazygit/k9s/ncspot/spotify-player/gdu, currently
  build-time from `modules/generic/theme-slots.nix`).

Rules for any new theme surface:

- Emit it from the single palette source in all three places that build a
  theme dir: `theme-runtime.nix` (Jylhis pair), its `mkSchemeThemeDir`
  (catalog/inline), and the CLI `generateThemeChangeBase` (matugen); the
  relink/reload leg goes in `activateThemeDir`.
- Stay IFD-free: pure string templating from `palette.hex` / base16 slots,
  never `readFile` of a built derivation such as `pkgs.jylhis-themes`
  (referencing it as a path is fine).
- Add a `testNixOS` assertion in `tests/eval/themes.nix` and update
  `site/src/content/docs/docs/configuration/theming.mdx`.
- If a surface needs a role with no palette token, report it as a
  `pkgs.jylhis-design-src` gap instead of inventing it locally.
- The swaps lean on conventions nothing else enforces: HM renders
  `services.mako.settings` into `xdg.configFile."mako/config"`,
  `programs.waybar.style` is a string, and GTK reads
  `design:platforms/gtk/jylhis-<mode>.css`. Recheck them on HM or design bumps.

## 2. Shell

### IPC/CLI verbs

- `modules/home/window-toggles.nix`, `hypridle.nix` and `screensaver.nix`
  still call `marchyo-shell ipc -n call -- shell …` directly; move them to
  `marchyo shell` verbs (DND/clear/notification-center need new verbs).
- `marchyo shell close` closes every panel; a `close <panel>` form needs a
  `closePanel(id)` in shell.qml.

### Control Center panel

One quick-settings surface over `Services/*` singletons, no new daemons.

1. Missing services, as `pragma Singleton` in `Services/` + qmldir:
   `BluetoothState` (wraps `Quickshell.Bluetooth.defaultAdapter`, used today
   directly by `Bar/BluetoothWidget.qml`) and `PowerProfileState` (wraps
   `PowerProfiles`, used directly by `Bar/PowerProfileWidget.qml`). Point both
   widgets at them.
2. Writable toggles: wifi on/off in `NetworkStatus` (nmcli radio) and
   Tailscale up/down in `Tailscale`, gated on `Config.tailscale`.
3. Toggle model: `Commons/QuickToggles.js` (or a `Services/QuickToggles`
   singleton) listing id, icon, label, `active`, `toggle()`, optional detail
   panel id, and availability, separate from presentation.
4. `Panels/ControlCenter.qml` on `Ui/Panel.qml` with `panelId:
   "controlcenter"`: tile grid, volume and mic sliders from `Audio`, tiles
   open the existing Audio/Network/Power/Tailscale panels as detail pages.
   Register in `Panels/qmldir` and `shell.qml`; new Style geometry is emitted
   by `packages/marchyo-shell/package.nix`.
5. Bar button widget + `barComponents` entry; `marchyo shell toggle
   controlcenter` and a Hyprland bind.
6. Eval tests for any new gating args in `modules/home/marchyo-shell.nix`;
   update `shell/README.md`. Done when every tile reflects and drives live
   state.

### Per-monitor config overrides (lower priority)

- Typed options module as the schema source (ref: serpantinum
  `nix/settings-options.nix`).
- Per-monitor overrides with an "always global" list (e.g. animations), ref:
  caelestia `monitors/<name>/shell.json`. Nix stays the default generator;
  reuse the `shell.json` watch pattern. Document under
  `site/src/content/docs/docs/configuration/`.

### Widgets and features (independent)

- Window overview / exposé with live previews + search (ref: end-4
  `modules/ii/overview/`).
- Privacy indicator for camera, next to the mic-in-use indicator.
- Clipboard image previews in `Launcher/ClipboardProvider.qml` (ref: end-4 `CliphistImage.qml`).
- Idle-inhibit-on-video: watch playerctl/PipeWire, drive `Caffeine`.
- Lock-keys widget (caps/num lock); needs a small XKB/libinput/sysfs helper.
- Persistent per-app audio routing across restarts (PipeWire metadata).
- Plugin system evolution: typed plugin kinds (widget/launcher/daemon) +
  lockfile on top of `Commons/PluginIndex.qml` (ref: DMS
  `Services/PluginService.qml`). Stays build-time only.
- Adopt Quickshell v0.3.0 natives once the pin has them: Networking (drop
  `nmcli` polling), PolkitAgent, `PwNodePeakMonitor`.
- Optional segmented bar look: two-tone segments with curved joins, pure QML
  `Shape` arcs in `shell/Ui/BarSection.qml`, filled from existing tokens so
  theme swaps recolor it. A presentation flag only, no layout changes, no
  image assets.

### Compositor effects (`modules/home/hyprland.nix` only)

- Per-namespace layer blur behind shell surfaces only.
- Shell-owned chrome: `border_size = 0`, QML draws frames.
- Snappy `popin` bezier; optional CRT `screen_shader` if a retro theme appears.

### Discrete stack removal (later milestone)

Vicinae, waybar, mako, SwayOSD and hyprlock stay as the
`marchyo.shell.enable = false` fallback until the shell is the only path.

## 3. Features

- **Share upload target.** `marchyo share` only stages paths on the clipboard;
  the upload backend is undecided.
- **Omarchy extras, low priority:** lifecycle hooks (`battery-low`,
  `theme-set`, `post-boot`), first-run onboarding, crash capture, per-theme
  keyboard RGB and backgrounds, dropbox/speedtest panels. Each needs a
  declarative shape (module/timer) first.

## 4. Manual

Chapters still stubs in `manual/` (end-user voice: prose-first, second person,
no Nix internals; minimal Starlight frontmatter; text first):

- 05 The Top Bar: stale Waybar tour; cover both bars keyed on
  `marchyo.shell.enable`, plus click behavior, tooltips, `SUPER+SHIFT+SPACE`.

## Won't do

- omarchy's update/migrate/refresh engine, AUR tooling, `omarchy-install-*`:
  replaced by `nixos-rebuild` + `flake.lock` + generations.
- Runtime plugin fetch/enable: plugins stay Nix-declared and baked.
- Dev-environment installers (mise etc.): per-project devenv.
- Per-model kernel patches (expose the kernel package choice instead), a
  Windows VM, omarchy's server edition.
- Plymouth runtime theming: never on screen during a session.
- Material You as default, transparency/blur/glass shell modes.

## Shell constraints (keep when touching `shell/`)

- `Bar/` owns no runtime state: every `Process`/`Timer`/`Connections`/
  `FileView`/`Socket` lives in a `Services/` singleton (contract-tested).
- Exactly one IPC mechanism, the `IpcHandler { target: "shell" }` in
  `shell.qml`; compat-shim handlers use per-plugin targets.
- Long-lived streams restart with backoff keyed on `onRunningChanged` (see
  `Services/Dictation.qml`); a dead stream reports in the tooltip.
- Every `Config.<tool>` is declared in `Commons/Config.qml` and baked by
  `packages/marchyo-shell/package.nix` (contract-tested).
- Bound subprocess output with a `maxChars` ceiling.
- Never point a `FileView` at a user-writable file; watch the directory as a
  doorbell (`preload: false`).
- Sandbox probes check the Wayland socket, not `WAYLAND_DISPLAY`.
- Disable `Behavior`s before a construction-time jump to 0 and re-enable
  `onFinished`, never `onStopped`.
- Nerd Font glyphs get stripped by editing tools: targeted edits only in `Bar/`.

## Process

- Verification stops at `nix build` / `nix flake check`; activating the running
  system is the user's action.
- Every new module/option gets a `testNixOS` eval test; option declarations
  stay platform-neutral (Darwin eval gate); keep
  `site/src/content/docs/docs/configuration/` in sync.
- `just fmt` + `just check` before each commit; conventional commits.

## References

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell): IPC CLI, plugins + lockfile, control center. Primary reference.
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell): launcher providers, per-monitor config, closest services split.
- [serpantinum](https://github.com/ilyamiro/serpantinum): typed Nix options module, CLI-as-IPC.
- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (`ii/` only): overview, quick-toggle models, fuzzysort, cliphist previews.
- [qylock](https://github.com/Darkkal44/qylock): lock-screen UX (skip its SDDM shim).
- [flickowoa yorha](https://github.com/flickowoa/dotfiles/tree/hyprland-yorha): compositor effects.
- [linux-retroism](https://github.com/diinki/linux-retroism), [rumda](https://github.com/Nytril-ark/rumda): readable reference QML.
- [ekremx25/quickshell](https://github.com/ekremx25/quickshell): notification centre.
- [awesome-quickshell](https://github.com/ziuus/awesome-quickshell): landscape index.
