# Marchyo Shell — engineering constraints and open backlog

Constraints that apply to the long-running QML shell, the open functionality
backlog, and reference projects/primitives to draw on when closing it.

## Constraints in force

- **Per-monitor instantiation duplicates seat-global work.** The bar is built
  once per screen, so `Bar/` owns no runtime state at all — every
  `Process`/`Timer`/`Connections`/`FileView`/`Socket` lives in a `Services/`
  singleton. Pinned by `tests/shell/contracts-test.sh`.
- **A long-lived stream needs a restart, not just a `running` binding.**
  `Services/Dictation.qml` restarts the `voxtype --follow` stream with
  exponential backoff (1s → 60s), reset by the first healthy line, keyed on
  `onRunningChanged` (covers both an ended process and a start that never
  happened — Quickshell drops `running` back to false with neither `started`
  nor `exited` when the binary doesn't exist). A dead stream reports in the
  tooltip, not by recolouring the glyph.
- **Baked tool paths are a contract.** Every `Config.<tool>` the QML reads is
  declared in the checked-in `Commons/Config.qml` and baked by
  `packages/marchyo-shell/package.nix` — contract-tested, so a tool can never
  read as `undefined` and spawn an empty `argv[0]` on a real host.
- **Exactly one IPC mechanism** (the stock `IpcHandler` in `shell.qml`),
  contract-pinned. No second bus.
- **Bound what you retain from a subprocess.** Collectors reading unbounded
  output carry a `maxChars` ceiling and reject over it.
- **Read paths you do not own defensively.** Never point a `FileView` at a
  user-writable state file; watch the **directory** as a doorbell
  (`preload: false`). Today the only `FileView` is on kernel-owned
  `/sys/class/backlight/*/brightness`.
- **Sandbox probes check the socket, not the env var.** Sandboxes pass
  `WAYLAND_DISPLAY` through while blocking `$XDG_RUNTIME_DIR`, so a bare
  variable check clears and then aborts.
- **Behaviors retargeted from a construction-time zero.** Disable `Behavior`s
  before the jump to 0, re-enable `onFinished`, never `onStopped` (which
  `restart()` fires spuriously).
- **Agent edits on glyph-dense files.** Multi-byte Nerd Font codepoints can be
  stripped by file-editing tools; `Bar/` widget files get targeted edits, not
  wholesale rewrites.

## Open backlog

- **Lock-keys widget** (caps/num lock). No native binding; needs a small
  helper reading XKB/libinput/sysfs.
- **Persistent per-application audio routing.** Per-app volume and meters
  ship; routing that *survives a restart* needs Pipewire metadata handling.
- **Dictation silence gate** — a gate so a silent recording does not
  hallucinate text; not confirmed for voxtype.

## Reference

Projects to draw on and track:

- **[caelestia-dots/shell](https://github.com/caelestia-dots/shell)** — the
  closest config to marchyo's `services/` + `modules/` + `components/` split,
  driven entirely off native bindings (Mpris, Pipewire, UPower, Notifications,
  Hyprland IPC). Pattern validation and a code reference, not a product to
  adopt.
- **[ekremx25/quickshell](https://github.com/ekremx25/quickshell)** —
  notification-centre reference (grouped history, DND, per-app filters).
- **[omarchy-mouse-battery](https://github.com/brianirish/omarchy-mouse-battery)**
  and **Solaarchy** — peripherals-battery references (UPower-first with a
  `solaar show` fallback for receivers the kernel won't bind).
- **[ziuus/awesome-quickshell](https://github.com/ziuus/awesome-quickshell)**
  — maintained landscape index.

Native API surface a monolith should adopt (no plugin registry): `Pipewire`,
`UPower`, `Mpris`, `Notifications`, `SystemTray`/SNI menus, `PanelWindow`,
`IpcHandler`, `Quickshell.Hyprland`. The native **Networking** service (would
let the network panel drop `nmcli` polling), **PolkitAgent**, and audio-meter
**`PwNodePeakMonitor`** are Quickshell **v0.3.0** additions — verify the
marchyo Quickshell pin before relying on them.

The shell is generated from the Jylhis design system (`tokens.json` →
`Commons/{Color,Style}.qml`). Material You palettes and
transparency/blur/glass modes stay rejected.
