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
