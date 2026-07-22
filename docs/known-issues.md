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

**If reconsidering iwd later:** confirm the roaming segfault is fixed upstream
(the `network_info_get_roam_frequencies` / neighbour-report path) in the iwd
version nixpkgs ships before switching `wifi.backend` back to `iwd`, and bring
`impala` back with it. Verify on a multi-AP network, not a single home router.
