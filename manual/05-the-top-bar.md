---
title: The Top Bar
description: Reading the top bar, what each segment does when you click it, and how to hide it.
---

The bar across the top of your screen tells you where you are and how the machine is
doing: workspaces on the left, the clock in the middle, and status on the right.
Most segments do something when you click them, and hovering over one shows a
tooltip with more detail.

The bar is part of the Marchyo shell, along with its panels, notifications, and
launcher. With `marchyo.shell.enable = false` there is no top bar.

## Hiding the bar

Press `Super + Shift + Space` to hide the bar, and press it again to bring it back.
This hides the bar on every monitor at once. You can also do it from a terminal with
`marchyo shell bar` (toggle), `marchyo shell bar off`, or `marchyo shell bar on`.

## The shell bar

By default the shell bar is a slightly translucent strip that spans the full width,
flush with the screen edges and the windows below it. For a rounded pill with a
small gap to the screen edges, set `marchyo.theme.appearance.floatingBar = true`. For solid surfaces instead of
the see-through glass look, set `marchyo.theme.appearance.surfaceAlpha = 1.0`.

For a segmented look, where each group of segments gets its own two-tone
background with rounded joins between groups, set
`marchyo.shell.settings.bar.style = "segmented"` and rebuild. Everything stays
in the same place; only the backgrounds change, and they follow your theme.
Set it back to `"flat"` (or remove the line) for the plain bar.

Each monitor gets its own bar. Some segments only show up when they have something
to say. A recording indicator, for example, appears only while a recording runs, and
the bar closes up the gap when a segment is hidden.

### Left and centre

The centre of the bar has three sections. The clock sits in `center`, at the exact
middle of the bar. `centerBegin` grows leftwards from the clock and `centerEnd`
rightwards, and both start empty. A widget that appears or changes size there never
moves the clock.

- **marchyo** is a label marking the start of the bar.
- **Workspaces** always shows 1 to 5, plus any other workspace in use on that
  monitor. The one you're on is highlighted, workspaces with windows are brighter
  than empty ones, and clicking a number switches to it.
- **Active window** shows the title of the focused window. If a long title is cut
  off, hover over it to read the whole thing.
- **Clock** shows something like `Mon 5 Oct · 14:30`. Click it to switch to the
  long form with the ISO week number, `5 October W41 2026`, and click again to
  switch back.

### Right side, from left to right

- **Tray**: a small `·` appears when apps have tray icons. Click it to show or hide
  the icons that are not pinned (see below). Left-click an icon to activate its app, right-click for its menu, and
  hover for its tooltip.
- **Media**: appears while a music or video player is running, showing the track
  title. Click to play or pause, right-click to skip to the next track, and scroll to
  go forward or back. The tooltip shows artist and title.

The next six segments form the **Indicators** cluster, one group between two rules.
Each one hides until it has something to show.

- **Screen recording**: a red icon while a recording runs. Click it to stop.
- **Reminders**: a count, in the accent colour, while reminders you set with `marchyo reminder`
  are waiting. Hover to see how many are pending.
- **Dictation**: a microphone glyph when dictation is on, red while recording and
  in the accent colour while transcribing. Click to start or stop recording. The
  tooltip shows the current state, and warns you if the dictation service stops
  answering.
- **Caffeine**: a mug that's lit while the screen is kept awake. Click it to keep the
  machine awake, and click again to let it sleep. It also lights up on its own while
  a video plays, and the tooltip then names the player.
- **Notifications**: a bell, with a count of unread notifications. Click to turn do
  not disturb on or off. Right-click to open your notification history.
- **Theme**: a sun or moon, matching the current theme. Click to cycle to the next
  theme. The tooltip names the one you're on.
- **Keyboard layout**: a short code such as `us`. Click to switch to the next layout,
  and hover for the full layout name.
- **Bluetooth**: shows how many devices are connected, or a crossed-out icon when
  Bluetooth is off. Click to open the Bluetooth manager. The tooltip lists connected
  devices.
- **Network**: Wi-Fi signal strength, a cable icon for wired, or a crossed-out icon
  when you're offline. Click to open the Network panel. The tooltip shows the
  network name, your address, and the interface.
- **Camera in use**: an amber webcam that appears whenever an app is using a
  camera. Hover to see which apps.
- **Microphone in use**: an amber microphone that appears whenever an app is
  recording from your mic. Hover to see which apps. Click to open the Audio panel.
- **Volume**: the output volume. Scroll to change it in steps of 5%, up to 150%.
  Right-click to mute or unmute. Click to open the Audio panel. The tooltip shows the
  output device and level.
- **CPU**: current CPU usage. Click to open the Monitor panel.
- **Power profile**: an icon for power saver, balanced, or performance. Click to
  cycle through them. The tooltip names the profile.
- **Peripherals**: appears when a wireless mouse, keyboard, or headset reports its
  battery, showing the lowest charge. It turns amber when a device runs low and red
  when it's nearly empty. Hover to see every device.
- **Battery**: the charge level, coloured from red through amber to green. It shows a
  charging icon while charging and a plug when you're on power but not charging.
  Click to open the Power panel. The tooltip shows the power draw, for example
  `4.2W↓ 87%`.
- **Control Center**: the last segment on the right. Click to open the Control
  Center.

### Panels

Several segments open a panel under the bar. Only one panel is open at a time, and
clicking anywhere outside it closes it. Each panel also has a button to the full
tool when you need more.

The AI agents panel marks limits that are more than an hour old as stale, and an agent whose
check failed because you are signed out shows a sign-in message instead of an error.
In the Display panel, Tab reaches a layout tile and selects its display, **Shift** with
the arrow keys moves the tile one step, and **R** rotates it.

A panel you open with a key chord or `marchyo shell open <panel>` takes keyboard
focus: **Esc** closes it, **Up**, **Down** and **Tab** move between its controls, and
**Enter** or **Space** activates the focused one. The mouse highlight is ignored
while you use the keyboard and returns when the pointer moves. For a look at every
control, run `marchyo shell gallery` or press `Super + Ctrl + Alt + G`.

- **Bluetooth** (`Super + Ctrl + B`): the adapter power switch, a scan switch, and
  every known device. Connected devices come first with their battery level. **Enter**
  on a device disconnects it, connects a paired one, or pairs a new one. Scanning stops
  when the panel closes. The full manager is `Super + Ctrl + Shift + B`.
- **Speed test** (`Super + Ctrl + Alt + P`): latency, download and upload against
  Cloudflare (about 125 MB moved), and a 512 MiB disk write and read in
  `~/.cache/marchyo`. Each test runs when you start it.
- **Dropbox** (`Super + Ctrl + Alt + D`): the sync state from `dropbox status` and a
  switch for the daemon. It needs the `dropbox` command on your PATH.
- **Audio** (volume segment or `Super + Shift + V`): volume up, down, and mute,
  a choice of output device, per-app volume, and which apps are using the
  microphone.
- **Network** (network segment or `Super + Shift + N`): connection status, network
  name and signal, a switch for the Wi-Fi radio, and a **Share (QR)** button that
  shows a code other devices can scan to join your Wi-Fi.
- **Power** (battery segment or `Super + Shift + B`): battery details, the power
  profile, and a button to the power menu.
- **Monitor** (CPU segment or `Super + Shift + M`): CPU, memory, disk, and
  temperature, with a button to btop.
- **Notification history** (right-click the bell): notifications you've received.
  Opening it marks them as read.

### The Control Center

The Control Center is a quick-settings panel: sliders for volume and microphone, and
tiles for Wi-Fi, Bluetooth, Tailscale, do not disturb, caffeine, night light, and the
power profile. Click a tile to flip it. Tiles with an arrow open the matching panel
for more detail, with a back button to return. Tiles for hardware you don't have are
left out.

Open it with `Super + Shift + Q` or the Control Center segment at the right end of
the bar.

Below the tiles, the **Appearance** section changes how the desktop looks without a
rebuild: window gaps, the bar position (top or bottom), the bar background (opaque,
glassy or clear) and reduce motion, which makes shell transitions instant. The
**Themes...** and **Wallpapers...** buttons open the pickers described next. The same
switches are available as `marchyo theme gaps`, `marchyo theme bar-position`,
`marchyo theme bar-background` and `marchyo toggle reduce-motion`.

### Theme and wallpaper pickers

`Super + Ctrl + T` opens the theme picker and `Super + Ctrl + Shift + W` the wallpaper
picker. Both show a grid with a large preview of the selected item. Type to filter,
use the arrow keys to move, press **Enter** to apply the selection and **Esc** to
close. The panel stays open after you apply, so you can try several. Click a tile
to apply it. A theme without a preview image shows a plain tile with its name.

Wallpaper thumbnails are cached in `~/.cache/marchyo/thumbs`. Until a thumbnail
exists, the picker shows the full image. Wallpapers come from the active theme, the
bundled set and `~/Pictures/Wallpapers`.

In the launcher, type `>font` to switch the terminal or interface font. Start with
`mono` or `ui` to list one kind, for example `>font ui inter`.

### Rearranging the bar

You can choose which segments appear in each part of the bar, and in what order.
Each section you set replaces that section of the default layout, and sections you
leave out keep their defaults. For example, a slimmer right side that keeps the
Control Center at the end:

```nix
marchyo.shell.settings.bar.layout.right = [
  { id = "marchyo.network"; }
  { id = "marchyo.audio"; }
  { id = "marchyo.battery"; }
  { id = "marchyo.separator"; }
  { id = "marchyo.controlCenter"; }
];
```

Rebuild, and the bar picks up the new layout without restarting. A few more
segments are available but not shown by default: `marchyo.nightLight` (click to turn
night light on or off), `marchyo.tailscale` (your Tailscale connection, click for
details), `marchyo.weather` (current conditions, click for a forecast panel),
`marchyo.agents` (the AI agent usage limit closest to its end, click for every
limit and its reset time), and `marchyo.lockKeys` (shows CAPS / NUM while Caps
Lock or Num Lock is on).
Three indicators stay hidden until needed: `marchyo.update` (the flake pins a newer nixpkgs than the
running system), `marchyo.disk` (the Nix store filesystem is nearly full) and
`marchyo.health` (`marchyo doctor` reports a failing check).
The full list of segment names is in the shell configuration reference.

### Rearranging the bar live

`marchyo bar` edits the layout without a rebuild. The edits are kept in
`~/.local/state/marchyo/shell/bar-layout.json`, the shell applies them over the layout
from your configuration, and they survive rebuilds.

```bash
marchyo bar put marchyo.cpu centerBegin      # move or add a segment (--at N picks the place)
marchyo bar move marchyo.cpu left            # shift it one place along its section
marchyo bar remove marchyo.media             # take a segment off the bar
marchyo bar set centerEnd marchyo.dnd marchyo.caffeine
marchyo bar list                             # the recorded edits
marchyo bar reset                            # back to the configured layout
marchyo bar background glassy                # opaque | glassy | clear
marchyo bar position bottom                  # top | bottom
```

Double-click an empty spot on the bar to step through the backgrounds.

### The tray drawer

By default every tray icon sits behind the `·` button. To keep some icons on the bar
and fold the rest, list them by tray id or title in the tray's settings:

```nix
marchyo.shell.settings.bar.layout.right = [
  { id = "marchyo.tray"; settings.pinned = [ "nm-applet" "Steam" ]; }
];
```
