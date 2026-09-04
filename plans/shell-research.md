# Research: what other Hyprland shells teach the marchyo shell

**Status: survey complete; the reliability findings marked _applied_ below are in
the tree.** A read of ten public Hyprland/Quickshell projects, looking for things
`shell/` should copy — first reliability and functionality, then styling. The
point was never to adopt anyone's product decisions (see the "Rejected
approaches" section of [`shell.md`](shell.md)); it was to find the failure modes
other people already hit in a long-running QML shell, and the surface area they
converged on.

## What was read

| Project | What it is | Signal |
| --- | --- | --- |
| [mryll/logibar](https://github.com/mryll/logibar) | Logitech HID++ battery widget: bash/python daemons + a waybar module + an Omarchy shell plugin | **Highest.** A `CLAUDE.md` and two test suites that are almost entirely about surviving hostile input inside someone else's long-running process |
| [ssupt/omarchy-audio-control](https://github.com/ssupt/omarchy-audio-control) | ~12k lines of QML + bash extending Omarchy's audio widget | **High.** Bounded capture, private-runtime locking, a mock-executable test suite, and the most complete audio feature list in the field |
| [glafeara/omalang](https://github.com/glafeara/omalang) | Keyboard-layout bar widget for Omarchy | **High.** Static "QML contract" tests, and the per-monitor-instantiation rule |
| [omacom/omarchy](https://github.com/omacom/omarchy) | The upstream reference: bar/panels/OSD/notifications as one Quickshell process | **High.** `docs/testing.md` and `agents/skills/shell-dev.md` |
| [adilzhanY/OpenHyprWhisper](https://github.com/adilzhanY/OpenHyprWhisper) | Local voice dictation with a Quickshell status pill | Medium. Dictation feature set (marchyo has `voxtype`) |
| [noctalia](https://docs.noctalia.dev/noctalia/) | A full Wayland desktop shell | Medium. Config surface + a strategic data point (below) |
| [Cybersnake223/Hypr](https://github.com/Cybersnake223/Hypr) | Arch rice; Quickshell launcher/menus + a screenshot overlay | Low-medium. One good idiom, one anti-pattern |
| [aadritobasu/HyprKenso](https://github.com/aadritobasu/HyprKenso), [zaeemali272/zenith](https://github.com/zaeemali272/zenith), [dizzi1222/dotfiles-dizzi](https://github.com/dizzi1222/dotfiles-dizzi) | Arch rices / install suites | Low. Imperative installers and dotfile trees; nothing transfers to a declarative flake |

### One strategic finding

**Noctalia is no longer a Quickshell shell.** `plans/shell.md` rejects it as
"a Quickshell shell whose layout and behavior is upstream's" — that rejection is
still right, but its premise is stale. Today's `noctalia-dev/noctalia` is ~1,250
C++ files built directly on Wayland + OpenGL ES with **no Qt and no GTK
dependency**; the QML shell was rewritten away. Nothing about our decision
changes (we still do not want someone else's product decisions), but the
comparison in `shell.md` should stop describing it as a QML peer.

## Reliability learnings

### 1. Per-monitor instantiation duplicates seat-global work — _applied_

> "Omarchy instantiates the widget once per monitor; OSD and IPC are seat-global
> and must stay single-owner or N monitors flash N stacked windows."
> — omalang, `tests/test-qml-contracts.sh`

`shell.qml` builds the bar inside `Variants { model: Quickshell.screens }`, so
**every widget is instantiated once per screen**. Three of ours owned a `Process`
or a `Timer` directly, which made them one subprocess *per monitor* answering a
question that has one seat-wide answer:

- `DictationWidget` — one long-lived `voxtype status --format json --follow`
  subscription per screen.
- `CaffeineWidget` — one `pgrep` fork every 5s per screen.
- `KeyboardLayoutWidget` — one `hyprctl devices -j` at startup plus one
  `activelayout` handler per screen.

Fixed the way this repo already handles shared state (`Audio`, `Power`,
`NetworkStatus`, `SystemStats`): new `Services/Dictation.qml`,
`Services/Caffeine.qml` and `Services/KeyboardLayout.qml` singletons own the
work, and the three widgets are now pure views. `shell/Bar/` no longer contains
a single `Process`, `Timer`, `Connections`, `FileView` or `Socket` — pinned by
a contract test so it stays that way.

### 2. A long-lived stream needs a restart, not just a `running` binding — _applied_

`running: <flag>` on a `--follow` process is a one-shot. When the producer exits
— daemon restart, crash, a `nixos-rebuild switch` swapping the binary — the
stream closes and nothing reopens it, so the widget froze on its last state for
the rest of the session. Cybersnake223's `IpcBus.qml` uses the bare idiom:

```qml
onExited: running = true
```

which is right in spirit and wrong in detail: a command that fails immediately
becomes a spawn loop inside the shell process. `Services/Dictation.qml` restarts
with exponential backoff (1s → 60s), reset by the first parsed line of a healthy
run, and reacts to `onRunningChanged` rather than `onExited` — which also covers
a start that never happened (see finding 3).

The widget reports a dead stream in its **tooltip**, not by recolouring the
glyph. That is logibar's rule:

> "A failed poll behind good data used to drop the whole face to 45% opacity,
> which restated the error in the same channel the battery ramp already uses."

Our colour channel already means "recording"; spending it on "voxtype is not
answering" would make one state read as another.

### 3. Quickshell's failed-start signalling is a real trap — _noted, low risk for us_

From logibar's `CLAUDE.md`, the single most valuable paragraph found:

> **The CLI always runs through `/bin/sh -c 'exec "$0" "$@"'`, never direct.**
> Handing Quickshell 0.3.1 a nonexistent binary can ABORT the whole shell inside
> the failed start — before any QML signal fires. sh always starts; a failed
> exec is sh exiting 127 (not found) or 126 (not executable).

And, on the panel that sat on "loading" for ever:

> A command that does not exist gives NEITHER `started` NOR `exited` — Quickshell
> just drops `running` back to false.

Marchyo is largely immune to the first half: `Commons/Config.qml` is regenerated
at build time with absolute `/nix/store` paths that are closure dependencies of
the package, so the binary cannot be missing on a host that has the shell. That
immunity is itself a contract, so the new contract test pins it: every
`Config.<tool>` the QML reads must be both declared in the checked-in
`Config.qml` **and** baked by `packages/marchyo-shell/package.nix`. A tool used
but not baked would read as `undefined` and spawn an empty `argv[0]` — a failure
that appears only on a real host.

The second half applies regardless, and `Services/Dictation.qml` now keys its
restart on `onRunningChanged` for exactly that reason.

### 4. Bound what you retain from a subprocess — _partly applied_

Both hardened projects cap what they will parse:

- logibar's QML `StdioCollector` has a 1 MiB `maxChars` **tripwire** — explicitly
  not a limit, since the collector has already buffered the stream; what it saves
  is parsing megabytes of unknown text into a process that lives all session.
- omarchy-audio-control's `audio_capture_bounded` rejects output one byte over
  the ceiling rather than truncating, validates the producer's exit code without
  relying on `pipefail`, and refuses a NUL byte.

Applied to `Services/KeyboardLayout.qml`'s `hyprctl devices -j` collector. The
remaining collectors (`nmcli`, `df`, `ls /sys/class/hwmon`) read fixed-shape
output from tools we bake; worth adding for symmetry, not urgent.

### 5. Read paths you do not own defensively — _not applicable today, but the rule is_

logibar's `read_bounded` is three lines and its comment carries the reasoning:

```bash
read_bounded() {  # read_bounded PATH MAXBYTES
    [[ -f "$1" ]] || return 1        # -f is false for FIFO, socket, directory and device
    LC_ALL=C dd if="$1" iflag=nonblock bs="$2" count=1 status=none 2>/dev/null
}
```

...with the load-bearing insight that **truncation is safe by construction** —
a half-read state file fails the numeric check, a half-read JSON fails the parse,
and all of those already mean "no data" on that path, never a wrong answer.

Their `Panel.qml` goes further and refuses to let a `FileView` touch a file the
shell does not own at all:

> A FileView opens and loads before any QML of ours can look at what it opened,
> so a same-user process that swaps the state file for a FIFO **stalls the
> shell**... The bounded-read guard in the CLI cannot help here: it protects the
> CLI's own reads, and the FileView never went through the CLI.

Their fix — one watch on the **directory** as a doorbell, `preload: false`,
never a reader — is the pattern to copy if the shell ever watches a file
another process writes. Today our only `FileView` is on
`/sys/class/backlight/*/brightness` (kernel-owned), so nothing is exposed.

### 6. Headless tests for a QML shell are possible, and we had none — _applied_

This is the biggest durable win, and it comes from two places.

**Omarchy** (`docs/testing.md`) keeps shell logic in plain `.js` modules ending
in a CommonJS guard:

> QML imports them directly and ignores the guard; Node loads them as CommonJS.
> That dual citizenship is what makes the shell's model logic unit-testable
> without a compositor.

**Omalang** pins cross-file agreements with grep, because the alternative is
nothing:

> Quickshell's typed `IpcHandler` prevents standalone `Panel.qml` linting, so
> these pin the agreements that a refactor on either side could silently break.

Before this pass, `nix flake check` covered exactly one thing about the shell
(that the wrapper bakes two env vars); everything else needed Quickshell and a Qt
platform plugin, i.e. `just -f shell/Justfile check` on a developer's machine.
Added, both wired into `nix flake check` as Linux-only `runCommand` checks:

- **`shell/Commons/Format.js`** + `tests/shell/format-test.js` (16 assertions,
  run by Node). Extracting the parsing immediately found a bug: `nmcli -t`
  escapes a literal colon inside a value as `\:`, and both nmcli parsers split
  on a bare `:` — an SSID of `Cafe: Free` was read as SSID `Cafe` with a signal
  strength of `Free` → `0%`. `splitTerse` handles the escaping, and an
  unparseable signal is now `-1` ("no reading") rather than `0`.
- **`tests/shell/contracts-test.sh`** (10 contracts): qmldir completeness both
  ways, `Bar/` widgets owning no runtime state, every `Services/` component
  actually being a singleton, the `Config.<tool>` chain of finding 3, and every
  `marchyo-shell ipc … -- shell <fn>` call in `modules/home/` resolving to a
  function in `shell.qml`. Each was verified to fail against a deliberate
  mutation before being kept — per logibar's warning about tests that move with
  the thing they check and so can never fail.

Two adjacent notes from the same sources, worth keeping in mind:

- Omarchy's `require_compositor` probe checks the **socket**, not
  `WAYLAND_DISPLAY`: "sandboxes pass the environment through while blocking
  `$XDG_RUNTIME_DIR`, so Quickshell clears a bare variable check and then aborts
  inside QGuiApplication — a core dump per launch where a skip belonged."
- Omarchy's shell-dev skill warns that agent file-editing tools can strip
  multi-byte codepoints, so widget files full of raw Nerd Font glyphs should get
  targeted edits rather than wholesale rewrites. Our `Bar/` widgets are exactly
  that kind of file.

### 7. Anti-patterns seen

- **Two parallel IPC mechanisms.** Cybersnake223's launcher runs both a
  Quickshell `IpcHandler` and an `inotifywait`-on-`/tmp` file bus, and its own
  `AGENTS.md` has to say "keep both in sync". Marchyo has one stock
  `IpcHandler`; the new contract test pins that there is exactly one, in
  `shell.qml`.
- **A tooltip meter measured against a width that does not exist yet.** logibar
  parks a `METER:<i>` placeholder in the line list and resolves it in the width
  pass — and notes the width pass *must* skip those lines or the measurement is
  circular. Relevant if our tooltips ever grow meters.
- **Behaviors retargeted from a construction-time zero.** logibar's "frozen
  Behavior lesson": an open animation must be its own `NumberAnimation` on a
  shared fraction, with the `Behavior`s disabled before the jump to 0 and
  re-enabled `onFinished` (not `onStopped`, which `restart()` fires spuriously).

## Functionality backlog

Ranked by what the field converged on versus what `shell/` has today. None of
this is applied; it is the shopping list this survey produced.

1. **Notification history.** Every mature shell has it and we have none — a
   missed toast is gone for ever. Noctalia's model is the one to copy: dismissing
   a toast only hides it, the entry stays in history and still counts as unread;
   history is cleared only explicitly or by a retention window.
2. **Per-monitor notification and OSD placement.** Ours render on the default
   screen. Noctalia's undock rule is the detail worth stealing: if none of the
   configured monitors are connected, fall back to all of them "so notifications
   never disappear silently".
3. **Per-sender notification rules** — match on app name/`desktop-entry`,
   `show_toast` / `save_history` / `bypass_dnd` / `override_duration`. Cheap
   given we already own the daemon, and it is the main thing mako users
   configure.
4. **A peripherals-battery widget.** logibar's whole reason to exist: a
   Logitech mouse/keyboard/headset reports over HID++ and UPower does not see
   it. It is a udev rule plus a small daemon publishing state; the aggregation
   and thresholds belong in one place that both the bar and any panel read.
5. **Audio panel depth** (from omarchy-audio-control, in rough value order):
   per-application routing that survives restarts, application volume sliders
   with live meters, port/profile selection, and a microphone-in-use indicator
   listing which applications are capturing. The last is a privacy feature more
   than an audio one.
6. **Dictation depth** (from OpenHyprWhisper, against our `voxtype`):
   push-to-talk (`start`/`stop` bound to press/release, not just `toggle`), a
   silence gate so a silent recording does not hallucinate text, a deterministic
   replacements table for domain jargon, and an enable/disable switch that stops
   the model daemon rather than leaving VRAM pinned.
7. **Clipboard history, lock-keys and a media/MPRIS widget** — the three
   remaining widgets present in essentially every peer bar and absent from ours.
8. **A freeze-frame region screenshot.** Cybersnake223's `hyprlens` freezes the
   screen before drawing the selection, so the capture matches what was on
   screen when the key was pressed.

## Styling learnings

Deliberately thin: marchyo's shell is generated from the Jylhis design system
(`tokens.json` → `Commons/Color.qml`), which is the point, so most of what these
projects do about theming is not available to us and should not be.

- **Material You / matugen wallpaper-derived palettes** (Cybersnake223,
  HyprKenso, zenith, OpenHyprWhisper) are the field default. Marchyo's fixed
  Field/Sheet palette is a deliberate opposite; noted, not adopted.
- **Worth taking:** noctalia separates `corner_radius_scale`, an animation
  `speed` multiplier and a `ui_scale` from the palette entirely — three axes our
  `Style.qml` does not expose, all of which are accessibility levers as much as
  taste ones. It also carries an explicit `high_contrast` flag.
- **Worth taking:** logibar tints a battery percentage along a *continuous*
  gradient between two theme tokens rather than switching colour at a threshold,
  so the value reads as a ramp instead of three discrete states.
- **Not worth taking:** transparency/blur/glass modes. They need compositor
  cooperation, they fight a token-driven palette, and they are where most of
  these projects' complexity lives.
