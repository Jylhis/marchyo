# Known issues and past incidents

A running log of hardware/software failures hit on marchyo systems, their root
cause, and how they were resolved. Newest first. When you diagnose a real
runtime failure (a crash, a service that won't stay up, a regression traced to a
specific commit), add an entry here so the next person (or agent) doesn't have
to re-derive it from the journal.

Each entry: **symptom**, **root cause**, **resolution**, and enough **evidence**
(the key journal lines, versions, commit) to recognise a recurrence.

---

## iwd backend Wi-Fi crashes (resolved 2026-07-22)

**Symptom.** Wi-Fi dropped repeatedly and would not stay connected after the
network TUI change. `journalctl -b` showed `iwd` segfaulting and being
restarted by systemd, with NetworkManager unable to reconnect cleanly during
the restart window.

**Root cause.** Commit `006c4e7` set
`networking.networkmanager.wifi.backend = "iwd"` in `modules/nixos/network.nix`
so the `impala` TUI (waybar Wi-Fi segment, `SUPER+CTRL+W`, system menu) could
drive the active stack — `impala` only speaks iwd. But **iwd 3.12 segfaults
during roaming**: in a multi-AP environment (one SSID served by ~7 access
points) iwd requests 802.11k neighbour reports and crashes in the roam-scan
path. nixpkgs `unstable` was also on iwd 3.12, so there was no newer packaged
version to move to, and the crash is in a code path iwd has no clean config
switch to disable.

Backtrace (from `coredumpctl` / `systemd-coredump`):

```
iwd[…]: 4-Way handshake failed for ifindex: 3, reason: 15
systemd-coredump: Process (iwd) dumped core.  SIGSEGV
  #0  network_info_get_roam_frequencies   (iwd)
  #1  station_roam_scan_known_freqs
  #2  station_neighbor_report_cb          ← crash handling an 802.11k neighbour report during roam
systemd[1]: iwd.service: Main process exited, code=dumped, status=11/SEGV
NetworkManager: Network.Connect failed: net.connman.iwd.InProgress: Operation already in progress
NetworkManager: Network.Connect failed: org.freedesktop.DBus.Error.NoReply: Remote peer disconnected
```

**Resolution.** Reverted to NetworkManager's default **wpa_supplicant** backend
(dropped `wifi.backend = "iwd"` entirely) and repointed all Wi-Fi TUI surfaces
from `impala` to **`nmtui`** (shipped with the `networkmanager` package, drives
NetworkManager directly):

- `modules/nixos/network.nix` — removed the iwd backend line.
- `modules/home/waybar.nix` — network segment `on-click` → `nmtui`.
- `modules/home/omarchy-binds.nix` — `SUPER+CTRL+W` → `nmtui`.
- `modules/home/menus.nix` — system menu **Wifi** entry → `nmtui`.
- `modules/home/hyprland.nix` — floating rule class `org.omarchy.impala` →
  `org.omarchy.nmtui`.
- `modules/nixos/packages.nix` — dropped `impala` from `tuiTools`.
- `tests/eval/waybar.nix`, `tests/eval/omarchy-binds.nix` — updated assertions
  (backing-services now asserts the backend is **not** iwd).
- `site/src/content/docs/docs/usage/hotkeys.mdx` — docs updated.

**Deep-research follow-up (2026-07-22).** A multi-source, adversarially
verified investigation confirmed:

- **It's a known, still-unfixed upstream bug.** The exact backtrace was filed
  against Alpine's iwd on 2023-02-02 ([aports #14605], still open). The kernel
  emits a low-RSSI/CQM event that netdev forwards to `station` before the
  connection is fully operational; `station` requests an 802.11k neighbour
  report that fails, runs a known-frequency roam scan, and dereferences an
  unpopulated/NULL `network_info` at `knownnetworks.c:378`. The path is **still
  NULL-unguarded in current iwd `master`**. It is a related-but-distinct defect
  from the already-merged 2021 "roaming before connected" and Jan-2023
  `155c266d` roam-scan fixes (both predate and are already in 3.12).
- **No upgrade path.** iwd 3.12 is the newest release (Gentoo stabilised it
  2026-07-20; no 3.13+ exists). nixpkgs unstable is on 3.12.
- **No verified fix or workaround.** The plausible "gate RSSI forwarding on
  `netdev->operational`" patch could not be pinned to a cherry-pickable commit,
  and a `[General].DisableRoamingScan` `main.conf` workaround could **not** be
  confirmed to avoid the crashing path (both refuted in verification). Treat any
  such change as experimental.
- **`reason: 15`** is the IEEE 802.11i 4-way-handshake timeout (client didn't
  answer EAPOL msg 1 or 3). It's the disruptive *trigger/context* that pushes
  iwd into the fragile roam path, **not** the segfault's own root cause, and has
  many possible causes (driver/firmware, RF, TX power). Fixing it would not
  necessarily fix the crash, nor vice versa.
- **wpa_supplicant is the correct long-term default, not a stopgap.** It is
  NetworkManager's default backend; the iwd backend is explicitly *experimental*
  and lacks feature parity ([Debian], [NixOS] and Arch wikis all say so).

**If reconsidering iwd later:** re-check `kernel.org` iwd git for a release
(3.13+) or commit that adds a NULL guard to
`network_info_get_roam_frequencies` / `station_roam_scan_known_freqs` (or
re-gates RSSI forwarding on `netdev->operational`) before switching
`wifi.backend` back to `iwd`; bring `impala` back with it. Verify on a real
multi-AP network, not a single home router. wpa_supplicant's roaming on this AP
fleet should also be observed for sticky-client behaviour; if it's poor, that's
the signal to revisit iwd once patched.

[aports #14605]: https://gitlab.alpinelinux.org/alpine/aports/-/issues/14605
[Debian]: https://wiki.debian.org/NetworkManager/iwd
[NixOS]: https://wiki.nixos.org/wiki/Iwd
