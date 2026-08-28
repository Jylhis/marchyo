# Plan: Marchyo Shell — a unified Quickshell desktop

**Revision 1 — draft.** Initial design skeleton for a custom
[Quickshell](https://quickshell.org) desktop shell, to be fleshed out before
implementation. Reference: omarchy 4.0.0.alpha's `shell/` (read
`../../omarchy/docs/omarchy-shell.md`, `../../omarchy/shell/README.md`, and
`../../omarchy/agents/skills/shell-dev.md`).

## Problem

Marchyo's desktop UI is a **composition of discrete Wayland components**, each its
own Home-Manager module and its own process:

- bar → `modules/home/waybar.nix` (Waybar)
- notifications → `modules/home/mako.nix` (mako)
- on-screen display → `modules/home/swayosd.nix` (SwayOSD)
- launcher / emoji / clipboard → `modules/home/vicinae.nix` (Vicinae)
- menus / power → `modules/home/menus.nix` (gum TUIs in floating ghostty)
- screensaver, lock → `modules/home/{screensaver,hyprlock}.nix`

This works, but the surfaces don't share a design runtime, state, or process. Each
is themed separately (see the "Stylix target disablement" gotcha — 13 surfaces are
hand-themed), each is a cold start, and cross-surface behavior (e.g. an OSD that
knows the bar's state) is impossible. Omarchy solved exactly this by collapsing the
whole desktop into **one long-running Quickshell (QML) process** where bar, panels,
OSD, notifications, lock, and background switcher are plugins sharing singletons and
an IPC bus.

Marchyo wants its own equivalent: a single, coherent, fully Jylhis-themed shell —
built declaratively and packaged in Nix — that can eventually retire the
waybar/mako/swayosd sprawl.

## Reference architecture (omarchy's shell)

One `quickshell -p <path>` process per session, launched from Hyprland autostart.
Everything runs inside as a plugin:

- **`shell.qml`** — `ShellRoot` entry point. Injects shared service singletons
  (`pluginRegistry`, `barWidgetRegistry`, `appLibrary`) as *properties* rather than
  re-importing singletons (relative-path singleton imports don't share state).
- **`Commons/`** — shared design-token singletons via `qmldir` (`Color.qml`,
  `Style.qml`, `Border.qml`, `Util.qml`), imported as `import qs.Commons`.
- **`Ui/`** — reusable QML component library (Button, Panel, Dropdown, Toggle,
  TextField, …).
- **`services/`** — host services: `PluginRegistry.qml` (discovers/validates
  plugins, tracks enabled state), `BarWidgetRegistry.qml`, `AppLibrary.qml`.
- **`plugins/`** — every feature as a plugin. A plugin is `manifest.json`
  (`schemaVersion: 1`, `id`, `kinds[]`, `entryPoints{}`, per-kind `defaults`/
  `schema`) + a QML entry `Item` (+ usually a `Model.js`). Kinds: `bar-widget`,
  `bar`, `panel`, `overlay`, `menu`, `service`. Panels/overlays/menus expose
  `open(payloadJson)`/`close()`; the host injects `omarchyPath`, `shell`,
  `manifest`, and the registries as properties. First-party services load at
  startup; the rest load on summon (`keepLoaded: true` to persist).
- **Config:** a single `~/.config/omarchy/shell.json` (layout + inline per-entry
  settings + enabled deviations). No deep merge, no per-plugin files.
- **IPC contract:** a `shell` target (+ per-plugin targets like `osd`, `media`,
  `notifications`, `background`). Methods: `ping`, `summon`, `hide`, `toggle`,
  `togglePanelAt`, `call`, `rescanPlugins`, `reloadConfig`, `applyTheme`,
  `toggleBarTransparency`, `setPluginEnabled`, `enablePlugin`. Summoning a panel is
  a ~30ms IPC call into the already-running process, not a cold start.

## Rejected approaches

- **Enable noctalia as-is** (`modules/home/noctalia.nix`, present-but-disabled).
  noctalia *is* a Quickshell shell, but it ships its own notification daemon that
  seizes `org.freedesktop.Notifications` (clashing with mako), is not themed from
  the Jylhis design system, and its layout/behavior is upstream's, not marchyo's.
  Adopting it means inheriting someone else's product decisions — the opposite of
  the curated, declarative control marchyo wants.
- **Keep the discrete-component status quo.** Zero build cost, but permanently
  forgoes shared state, a single theme runtime, and cross-surface behavior; leaves
  13 hand-themed surfaces to maintain.
- **Fork omarchy's `shell/`.** Closest to the target, but omarchy's shell is wired
  to omarchy's imperative `bin/omarchy-*` world (`omarchy-launch-shell`, theme
  push via `applyTheme`, `~/.config/omarchy/` layout) and its Arch packaging. We'd
  spend the effort ripping that out. Better to take it as the *reference design*
  and build a clean, Nix-native shell that reuses its architecture (plugin model,
  singleton injection, IPC contract) without its plumbing.

**Chosen:** build a marchyo-native Quickshell shell from scratch, borrowing
omarchy's proven architecture (single process, manifest plugins, injected
singletons, IPC summon/toggle), packaged and themed the marchyo way.

## Nix packaging plan

- Add **`quickshell`** as a flake input (it is not one today — it only arrives
  transitively via noctalia). Prefer the upstream flake or nixpkgs `quickshell`;
  pin it in `flake.lock`.
- Create **`packages/marchyo-shell/`** — the QML source tree (`shell.qml`,
  `Commons/`, `Ui/`, `services/`, `plugins/`) + a wrapper that runs
  `quickshell -p <store-path>`. The QML lives at top-level **`shell/`** in the repo
  (already reserved) and the package copies it into the store.
- Wire it into the **Linux block of `overlay.nix`** (same pattern as
  `hyprmon`/`noctalia`): `marchyo-shell = final.callPackage ./packages/marchyo-shell { }`.
- Add **`modules/home/marchyo-shell.nix`**, gated behind a new
  `marchyo.shell.enable` option (declared in `modules/nixos/options/`). It installs
  the package, adds the Hyprland autostart `exec-once`, and writes the initial
  `shell.json`. Default **off** initially; it does not touch waybar/mako/swayosd
  until it reaches parity, then a feature flag flips the desktop from the discrete
  stack to the unified shell.
- Coverage: a `tests/eval/shell.nix` eval test for the module + option, following
  the existing per-feature test pattern.

## Theming bridge

The shell's design-token singletons (`Commons/Color.qml`, `Commons/Style.qml`)
should be **generated from the Jylhis design system**, not hand-authored, so the
shell tracks the same `tokens.json` every other surface does. Reuse the existing
`modules/generic/jylhis-palette.nix` `mkPalette { variant, pkgs, lib }` mechanism
to emit a `Color.qml` (and font sizes from `marchyo.theme.fontScale` via
`lib/font-scale.nix`) at build/activation time. Dark = Jylhis Field, light = Jylhis
Sheet, matching the rest of marchyo. Runtime variant switch (`marchyo theme`) would
push new colors over IPC (omarchy's `applyTheme`) rather than rebuild.

## Phasing

Each phase behind `marchyo.shell.*` flags; nothing is removed from the discrete
stack until the shell reaches parity for that surface.

- **Phase 0 — packaging spike.** `quickshell` input + `packages/marchyo-shell/` +
  `modules/home/marchyo-shell.nix`; a blank `ShellRoot` renders under Hyprland.
  Proves the Nix packaging, autostart, and QML-from-store path.
- **Phase 1 — bar.** Port the Waybar segment set (workspaces, active window, clock,
  tray, audio, network, battery, DND, dictation, updates) as bar widgets. Behind a
  flag that, when on, disables `waybar.nix`.
- **Phase 2 — panels + OSD.** audio/network/power/monitor panels; retire SwayOSD.
- **Phase 3 — notifications.** A notifications plugin owning
  `org.freedesktop.Notifications`; retire mako (the noctalia conflict, done right).
- **Phase 4 — lock + launcher.** Lock surface; evaluate whether to keep Vicinae
  (a strong standalone launcher) or bring launching in-shell.

## Open questions

- **(Open)** Config surface: mirror omarchy's single `shell.json`, or express
  layout declaratively through `marchyo.shell.*` Nix options and *generate*
  `shell.json`? The shell currently bakes everything at build time (no runtime
  config file); revisit if runtime tweaks are needed. (Marchyo's declarative ethos
  argues for generated defaults with an optional runtime overlay.)
- **(Resolved)** Third-party plugin story: **rejected.** See the Phase 2
  "Architecture decision" — marchyo does not port omarchy's
  `PluginRegistry`/manifest/`shell.json` machinery; surfaces are plain in-process
  QML. No git-clone-into-`~/.config` plugins; a Nix-declared list can be added
  later if ever needed.
- **(Resolved)** Keep Vicinae as the launcher: **yes.** See the Phase 4 status;
  the shell integrates with Vicinae rather than reimplementing a launcher.

## Status

- **Phase 0 — done.** `quickshell` (from nixpkgs), `packages/marchyo-shell/`,
  `modules/home/marchyo-shell.nix`, the `marchyo.shell.enable` option, overlay +
  flake wiring, and eval tests all landed; the tokens→QML theming bridge works.
- **Phase 1 (bar) — done.** A monolithic Jylhis-themed bar at waybar parity:
  `Ui/BarItem` primitive + `Bar/` widgets composed by `shell.qml`, driven by native
  Quickshell service bindings (Hyprland, Pipewire, UPower incl. PowerProfiles,
  SystemTray, Bluetooth, Networking, plus a `/proc/stat` FileView for CPU) and, for
  the tool-backed widgets, absolute `/nix/store` paths baked into a generated
  `Commons/Config.qml`. `Commons/Color.qml` carries the full palette+status token
  set; `Commons/Style.qml` scales geometry from `marchyo.theme.fontScale` and bakes
  the `dictationIndicator`/`menusEnabled` feature flags.
  - **Tool-path baking landed:** keyboard-layout / DND / dictation / caffeine
    widgets, click-to-launch-TUI actions (audio→wiremix, cpu→btop, network→nmtui,
    battery→power menu, bluetooth→bluetui), and `nmcli`-backed network SSID+signal —
    all reuse waybar's exact commands and `org.omarchy.*` float classes.
  - **Cutover landed:** `marchyo.shell.enable` now disables `waybar.nix` (mutually
    exclusive); mako/swayosd stay until Phases 2–3. See
    [../shell/README.md](../shell/README.md).
  - **Cosmetic parity done:** the tray expander (`·` toggle to show/hide icons)
    and the clock `format-alt` toggle (compact vs long ISO-week form) now match
    waybar; nothing waybar renders is missing from the bar.
- **Phase 2 (panels + OSD) — in progress.**
  - **OSD landed.** `shell/Osd/Osd.qml`: one bottom-centred, click-through
    overlay for volume / mic-mute / brightness, triggered **natively** (Pipewire
    bindings + a watched `/sys/class/backlight` node), no external poke and no
    IPC. Enabling the shell now also retires SwayOSD: `modules/home/swayosd.nix`
    stands its server down and `modules/home/hyprland.nix` routes the media keys
    through the silent `wpctl`/`brightnessctl` path so the shell draws the
    overlay. Eval tests assert the swayosd/shell mutual exclusion.
    - *Open live-verify:* sysfs `inotify` delivery for the backlight node is
      unverifiable offscreen. If a brightness key doesn't flash the overlay on a
      real host, fall back to a one-line IPC poke from the bind (`qs ipc call`).
  - **Architecture decision (supersedes the "plugin registry + IPC bus" wording
    above).** marchyo does **not** port omarchy's `PluginRegistry` /
    `BarWidgetRegistry` / `manifest.json` system: that machinery exists almost
    entirely to discover and hot-reload *third-party* plugins from `~/.config`
    and persist enable-state to `shell.json` — exactly the imperative,
    unsandboxed third-party-plugin story this plan already rejects (see "Open
    questions"). The reusable core is just stock Quickshell `IpcHandler` (native
    `qs ipc`, no custom bus) plus plain in-process objects/singletons. Panels
    will follow the same lightweight shape: a `bool open` controller + a
    layer-shell `PanelWindow` card anchored to its bar button, backed directly by
    the native service, toggled in-process on bar-widget click (IPC only for
    keybind summons).
  - **Panels landed.** `Services/PanelManager.qml` (a singleton holding the one
    open panel id, mutual exclusion), `Ui/Panel.qml` (layer-shell overlay card +
    outside-click dismiss) and `Ui/PanelButton.qml`, plus four panels in
    `Panels/`: **audio** (Pipewire volume/mute + output-device picker), **network**
    (Networking + nmcli status), **power** (UPower battery + PowerProfiles
    selector), and **monitor** (CPU/mem/disk/temp meters from a shared
    `Services/SystemStats` singleton + `df` + hwmon). Each is opened by clicking
    its bar widget (`PanelManager.toggle(id)`) and keeps a button to the matching
    TUI/menu (wiremix / nmtui / power menu / btop) as an escape hatch. No new Nix
    option — pure in-process QML; panels render on the default screen (per-output
    deferred).
  - **Keybind summons landed.** A single stock `IpcHandler { target: "shell" }`
    in `shell.qml` (`togglePanel`/`openPanel`/`closePanels`/`osdShow`); Hyprland
    binds (`modules/home/hyprland.nix`, gated on `shellEnabled`) call
    `marchyo-shell ipc -n call -- shell togglePanel <id>`. The `marchyo-shell`
    wrapper bakes its own `-p`, so the call self-targets the running instance —
    no instance discovery. This is the shell's only IPC; no custom bus.
  - **Next in Phase 2:** OSD live-verify on a real host (brightness sysfs poke
    fallback, panel service bindings). Phase 2 is otherwise **feature-complete**;
    the remaining item is live verification, so work continues into Phase 3
    (notifications).
- **Phase 3 (notifications) — done.**
  - **Notification server + toasts landed.** `Notifications/NotificationDaemon.qml`
    instantiates a Quickshell `NotificationServer` that owns
    `org.freedesktop.Notifications` (body + markup + actions + image capabilities,
    no inline reply / persistence). Incoming notifications are retained
    (`tracked`) and handed to a shared `Services/NotificationState` singleton;
    `Notifications/NotificationList.qml` renders them newest-first as a top-right
    layer-shell stack of `NotificationPopup` cards (sharp-cornered, 2px
    urgency-coloured border, per-urgency auto-expire, click-to-dismiss, action
    pills). Native throughout; no custom bus.
  - **DND is in-shell state.** `NotificationState.dnd` replaces mako's
    `mode=do-not-disturb`; the bar's DndWidget binds/toggles it in-process (no
    `makoctl`, no poll), and the keybind/CLI reach it through the `shell` IPC
    (`toggleDnd` / `clearNotifications`). Under DND non-critical notifications
    queue and reappear when it clears; critical always show.
  - **Mako cutover landed.** Enabling the shell stands mako down
    (`modules/home/mako.nix`, mutually exclusive like waybar/swayosd), routes the
    `modules/home/window-toggles.nix` DND/dismiss binds through the shell IPC, and
    the shell package no longer bakes `makoctl` at all. Eval tests assert the
    mako/shell mutual exclusion. No new Nix option (reuses `marchyo.shell.enable`).
  - **Live-verify:** D-Bus name acquisition, real toast rendering/stacking,
    action round-trips, `Quickshell.iconPath` resolution, and the markup subset
    need a Wayland host with mako actually retired.
- **Phase 4 (lock + launcher) — scoped, not started.**
  - **Launcher: keep Vicinae (decision).** This resolves the third Open Question.
    Vicinae is a strong standalone launcher (emoji/clipboard/apps) already themed
    and wired (`modules/home/vicinae.nix`); reimplementing it in-shell is a large
    effort for no user-visible gain. The shell integrates with it rather than
    replacing it (the battery/power widgets already fall back to `vicinae toggle`
    when menus are off). Revisit only if a launcher needs shell-shared state.
  - **Lock surface: the one remaining implementation, intentionally deferred.**
    Quickshell provides `WlSessionLock`, but a lock screen must be verified live
    before shipping: a lock surface that fails to render or accept input locks the
    user out of the session. It also needs a real Hyprland/greetd + PAM loop that
    cannot be exercised offscreen. So it is left for a session with host access,
    where it can replace `hyprlock`/`screensaver` behind the same mutual-exclusion
    cutover pattern used for waybar/swayosd/mako.
- **Outstanding (host-only):** live verification of the OSD (brightness sysfs
  poke), the panels' service bindings, the IPC keybind round-trips, and the
  notification surface (bus acquisition, rendering, actions, icons) on a real
  Hyprland host. Everything buildable/offscreen-testable in Phases 0–3 plus the
  bar's full waybar parity is complete and committed.
