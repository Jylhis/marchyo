# Research: what other Hyprland shells teach the marchyo shell

**Status: survey of ten public Hyprland/Quickshell projects, 2026-08.** The
reliability findings have been applied to the tree (see the summary); what
remains here is the rules worth keeping in force plus the functionality
backlog that is still open. The point was never to adopt anyone's product
decisions — it was to find the failure modes other projects already hit in a
long-running QML shell, and the surface area they converged on.

## Applied to the tree (summary)

- **Per-monitor instantiation duplicates seat-global work.** The bar is built
  once per screen, so every `Process`/`Timer` moved into `Services/`
  singletons (`Dictation`, `Caffeine`, `KeyboardLayout` were the offenders);
  `Bar/` owns no runtime state at all — pinned by
  `tests/shell/contracts-test.sh`.
- **A long-lived stream needs a restart, not just a `running` binding.**
  `Services/Dictation.qml` restarts the `voxtype --follow` stream with
  exponential backoff (1s → 60s), reset by the first healthy line, keyed on
  `onRunningChanged` (covers both an ended process and a start that never
  happened — Quickshell drops `running` back to false with neither
  `started` nor `exited` when the binary doesn't exist). A dead stream
  reports in the tooltip, not by recolouring the glyph.
- **Baked tool paths are a contract.** Every `Config.<tool>` the QML reads is
  declared in the checked-in `Commons/Config.qml` and baked by
  `packages/marchyo-shell/package.nix` — contract-tested, so a tool can never
  read as `undefined` and spawn an empty `argv[0]` on a real host.
- **Headless tests.** Omarchy's dual-citizenship `.js` pattern and omalang's
  grep contracts produced `shell/Commons/Format.js` + `tests/shell/format-test.js`
  (16 Node assertions; extracted parsing fixed a real bug — nmcli's `\:`
  colon escaping split `Cafe: Free` into SSID `Cafe` + signal `Free`) and
  `tests/shell/contracts-test.sh` (qmldir completeness both ways, no
  stateful `Bar/` widgets, `Services/` singletons, the Config tool chain,
  and every IPC call in `modules/home/` resolving to a `shell.qml` function).
  Both run in `nix flake check` as Linux-only checks — background in
  [`docs/ci-and-testing.md`](../docs/ci-and-testing.md).
- **Exactly one IPC mechanism** (the stock `IpcHandler` in `shell.qml`),
  contract-pinned. The two-bus anti-pattern from Cybersnake223's launcher
  stays a warning.
- **Freeze-frame region capture** (hyprlens's idea) landed via
  `grimblast --freeze` in `marchyo capture screenshot --target area` and the
  OCR path.

## Rules still in force

- **Bound what you retain from a subprocess.** logibar's 1 MiB `maxChars`
  tripwire and omarchy-audio-control's reject-over-ceiling collector
  motivated the bounded `hyprctl devices -j` collector in
  `Services/KeyboardLayout.qml`. The remaining collectors (`nmcli`, `df`,
  `ls /sys/class/hwmon`) read fixed-shape output from tools we bake; adding
  the same cap is worth doing for symmetry, not urgent.
- **Read paths you do not own defensively.** logibar's `read_bounded`
  (truncation-safe by construction) and the never-reader FileView (watch the
  **directory** as a doorbell, `preload: false`) are the pattern to copy if
  the shell ever watches a file another process writes. Today the only
  `FileView` is on kernel-owned `/sys/class/backlight/*/brightness`, so
  nothing is exposed — but never point one at a user-writable state file.
- **Sandbox probes check the socket, not the env var** (omarchy's
  `require_compositor`): sandboxes pass `WAYLAND_DISPLAY` through while
  blocking `$XDG_RUNTIME_DIR`, so a bare variable check clears and then
  aborts. Relevant to any future offscreen/CI harness expansion.
- **Behaviors retargeted from a construction-time zero** (logibar's frozen
  `Behavior` lesson): disable `Behavior`s before the jump to 0, re-enable
  `onFinished`, never `onStopped` (which `restart()` fires spuriously).
  Relevant if tooltips ever grow meters (logibar's `METER:<i>` width-pass
  note).
- **Agent edits on glyph-dense files:** multi-byte Nerd Font codepoints can
  be stripped by file-editing tools; `Bar/` widget files get targeted
  edits, not wholesale rewrites (omarchy's shell-dev skill).

## Functionality backlog (open items, ranked)

From what the field converged on versus what `shell/` has today.

1. **Notification history.** Every mature shell has it and we have none —
   a missed toast is gone forever (no persistence; DND only queues live
   popups, capped at 20). Noctalia's model is the one to copy: dismissing a
   toast only hides it, the entry stays in history and still counts as
   unread; cleared only explicitly or by a retention window.
2. **Per-sender notification rules** — match on app name/`desktop-entry`,
   `show_toast` / `save_history` / `bypass_dnd` / `override_duration`.
   Cheap given we already own the daemon; the main thing mako users
   configure. (Pairs with history above.)
3. **A peripherals-battery widget.** logibar's whole reason to exist: a
   Logitech mouse/keyboard/headset reports over HID++ and UPower doesn't
   see it (marchyo ships `programs.solaar`, but the shell has no battery
   widget for it). A udev rule plus a small daemon publishing state; the
   aggregation and thresholds belong in one place that both the bar and any
   panel read.
4. **Audio panel depth** (from omarchy-audio-control, in rough value
   order): per-application routing that survives restarts, application
   volume sliders with live meters, port/profile selection, and a
   microphone-in-use indicator listing which applications are capturing
   — the last is a privacy feature more than an audio one.
5. **Dictation depth** (from OpenHyprWhisper, against our `voxtype`):
   push-to-talk (`start`/`stop` bound to press/release, not just `toggle`),
   a silence gate so a silent recording does not hallucinate text, a
   deterministic replacements table for domain jargon, and an
   enable/disable switch that stops the model daemon rather than leaving
   VRAM pinned.
6. **Lock-keys and a media/MPRIS widget** — the remaining widgets present
   in essentially every peer bar and absent from ours (clipboard history
   is already covered by Vicinae + cliphist, so it is off this list).

Note: toast/OSD placement was on this list and is resolved — notifications
and the OSD follow the focused output (`Screens.focused`), not the default
screen.

## 2026-09 update: Quickshell-native implementation paths

**Status: a second, backlog-driven survey (2026-09) of the current Quickshell
config landscape, 3-vote adversarially verified (22/25 claims confirmed).**
The 2026-08 pass asked "what failure modes did other long-running QML shells
hit"; this pass asked "for each open backlog item, what is the first-party
Quickshell primitive and the best reference implementation to copy". The
headline is that nearly every backlog item below is buildable on Quickshell's
built-in service API, so none of them forces the third-party-plugin story
marchyo rejected.

### New projects worth studying (beyond the 2026-08 ten)

- **[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** is the
  single most relevant new config and the reference implementation for most
  items below. It independently converged on marchyo's own split:
  `services/` (backend `pragma Singleton`s holding seat-global state and
  continuous processes, owning an `IpcHandler`), `modules/` (feature groups),
  `components/` (reusable UI), `utils/`. It drives everything off native
  bindings (Mpris, Pipewire, UPower, Notifications, Hyprland IPC). Treat it as
  pattern validation and a code reference, not a product to adopt.
- **[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)**
  splits QML UI from a separate Go backend daemon over a Unix socket
  (`dms ipc call spotlight toggle`). Informative, but at odds with marchyo's
  single-`IpcHandler` QML-singleton rule; noted, not recommended.
- **[skill-shell issue #11](https://github.com/ASafaeirad/skill-shell/issues/11)**
  ("One panel registration, not eighteen", open/unimplemented) proposes
  deriving a panel's open-state, IPC target, and `GlobalShortcut` from one
  declarative panel name instead of scattering registration across five files.
  A cheap DRY refactor directly applicable to `Services/PanelManager.qml` plus
  the one `IpcHandler`.
- **[ziuus/awesome-quickshell](https://github.com/ziuus/awesome-quickshell)**
  is the maintained landscape index (Caelestia, end-4/illogical-impulse,
  Noctalia, DankMaterialShell, Ambxst, reusable libs) to track going forward.

### Backlog items, mapped to native primitives

Keyed to the ranked backlog above.

1. **Notification history (item 1).** The native `Notification` type is
   `Retainable`; its read/write `tracked` property dismisses-without-deleting,
   which is the basis for hide-not-delete history.
   **[ekremx25/quickshell](https://github.com/ekremx25/quickshell)** is a
   working notification-centre reference (grouped history, DND, per-app
   filters; config in `notification_config.json` with atomic writes).
   **Refuted, and the reason this stays non-trivial:** there is *no*
   `keepOnReload` / `trackNotifications` / `persistNotifications` property on
   `NotificationServer`; cross-restart persistence must be built by serializing
   to disk. Naive retention of a destroyed `Notification` segfaults without a
   `RetainableLock` (impasto issue #3). Budget for both.
2. **Per-sender rules (item 2).** Each `Notification` exposes readonly
   `appName` / `appIcon` / `desktopEntry`, the freedesktop match keys, so
   `show_toast` / `save_history` / `bypass_dnd` / `override_duration` are a
   match-table over properties we already receive. Pairs with item 1.
3. **Peripherals battery (item 3).** Native `UPower.devices`
   (`ObjectModel<UPowerDevice>`, event-driven, no polling) already covers most
   wireless mice/keyboards.
   **[omarchy-mouse-battery](https://github.com/brianirish/omarchy-mouse-battery)**
   binds it directly and falls back to polling `solaar show` (default 300s)
   *only* while UPower reports no device, specifically for the Logi Bolt
   receiver (`046d:c548`) the kernel will not bind.
   **Solaarchy** (Solaar Python HID++ backend + udev hidraw rules) is the
   richer per-device version. Port note: the Solaar path is a non-QML runtime
   dependency, so package it as a Nix-provided helper the QML polls, consistent
   with the "baked tool paths are a contract" rule, never as a plugin.
4. **Audio panel depth (item 4).** Native `Quickshell.Services.Pipewire`
   exposes `nodes` as an `ObjectModel<PwNode>` filterable by `isStream`
   (application vs hardware), `isSink`, and `audio`, giving per-app volume UI;
   `links` / `linkGroups` expose source/target nodes so per-app routing can be
   *read*. **v0.3.0 added `PwNodePeakMonitor`** for live per-stream meters.
   Caelestia's `services/Audio.qml` is the reference. Caveat: enumeration,
   per-app volume, and meters are unambiguous; per-app routing that *survives a
   restart* needs Pipewire metadata handling and was not confirmed in any
   surveyed config (Caelestia persists only default sink/source names).
5. **Dictation PTT (item 5).** `voxtype record start` / `voxtype record stop`
   bound to press/release via Hyprland `bind`/`bindr` gives true push-to-talk
   today; it stays a CLI shelled out through the existing IpcHandler+process
   model, not a QML binding. The deeper asks (silence gate, replacements
   table, VRAM-freeing enable/disable) were not confirmed for voxtype and
   remain open.
6. **Media/MPRIS and lock-keys (item 6).** The MPRIS half is a straightforward
   native adopt: `Quickshell.Services.Mpris` exposes `players` as an
   `ObjectModel<MprisPlayer>` (auto-discovered `org.mpris.MediaPlayer2*`), used
   in Caelestia. The caps/num lock half produced *no* source or native binding
   in either survey; it likely needs a small helper reading XKB/libinput/sysfs.

### Native API surface a monolith should adopt

All first-party, no plugin registry: `Pipewire`, `UPower`, `Mpris`,
`Notifications`, `SystemTray`/SNI menus (`QsMenuHandle` / `QsMenuOpener` /
`QsMenuEntry` / `QsMenuAnchor`), `PanelWindow`, `IpcHandler`, and
`Quickshell.Hyprland` (IPC, events, `GlobalShortcut`).

**Version gate (verify the marchyo Quickshell pin first):** the native
**Networking** service (NetworkManager D-Bus backend; would let the network
panel drop `nmcli` polling), the **PolkitAgent**, and audio-meter
**`PwNodePeakMonitor`** are all Quickshell **v0.3.0** (2026-05) additions. The
notification and core Pipewire/UPower primitives above are from v0.2.0/v0.2.1
docs and are safe on the older pin.

## Styling learnings (thin by design)

The shell is generated from the Jylhis design system (`tokens.json` →
`Commons/Color.qml`), which is the point; Material You palettes and
transparency/blur/glass modes stay rejected.

- **Worth taking:** noctalia separates `corner_radius_scale`, an animation
  `speed` multiplier and a `ui_scale` from the palette entirely — three
  accessibility/taste axes our `Style.qml` does not expose, plus an explicit
  `high_contrast` flag.
- **Worth taking:** logibar tints a battery percentage along a *continuous*
  gradient between two theme tokens rather than switching colour at a
  threshold, so the value reads as a ramp instead of three discrete states.
- **Worth taking (2026-09):** Caelestia is the clearest copyable design for
  the axes noctalia only named. It splits a user-facing `shell.json` from a
  separate `shell-tokens.json` holding rounding, spacing, padding, font size,
  and animation duration/curve tokens; the appearance *scale* values in
  `shell.json` multiply the base tokens to produce the final computed values,
  with per-monitor overrides under `monitors/<name>/`. That is exactly the
  palette-independent `corner_radius_scale` / animation-speed / `ui_scale`
  layering marchyo wants, and it maps onto the existing `tokens.json` ->
  `Commons/{Color,Style}.qml` generation rather than fighting it.
