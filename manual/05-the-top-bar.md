---
title: The Top Bar
description: Reading the top bar, what each segment does when you click it, and how to hide it.
---

The bar across the top of your screen tells you where you are and how the machine is
doing: workspaces on the left, the clock in the middle, and status on the right.
Most segments do something when you click them, and hovering over one shows a
tooltip with more detail.

Which bar you see depends on one setting. With the Marchyo shell turned on, the bar
is part of the shell, along with its panels, notifications, and launcher:

```nix
marchyo.shell.enable = true;
```

The shell is off by default. Without it, the top bar is Waybar. The two bars look
similar and cover the same ground, but the shell bar can open panels and you can
rearrange it. Both are covered below.

## Hiding the bar

Press `Super + Shift + Space` to hide the bar, and press it again to bring it back.
With the shell, this hides the bar on every monitor at once. You can also do it from
a terminal with `marchyo shell bar` (toggle), `marchyo shell bar off`, or
`marchyo shell bar on`.

With Waybar, the same key hides and shows Waybar. To stop Waybar entirely, use
`marchyo toggle waybar`.

## The shell bar

By default the shell bar floats as a rounded, slightly translucent pill with a small
gap to the screen edges. If you prefer a flat strip that spans the full width, set
`marchyo.theme.appearance.floatingBar = false`. For solid surfaces instead of
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

- **Screen recording**: a red icon while a recording runs. Click it to stop.
- **Reminders**: a count, in the accent colour, while reminders you set with `marchyo reminder`
  are waiting. Hover to see how many are pending.
- **Tray**: a small `·` appears when apps have tray icons. Click it to show or hide
  the icons. Left-click an icon to activate its app, right-click for its menu, and
  hover for its tooltip.
- **Media**: appears while a music or video player is running, showing the track
  title. Click to play or pause, right-click to skip to the next track, and scroll to
  go forward or back. The tooltip shows artist and title.
- **Dictation**: a microphone glyph when dictation is on, red while recording and
  in the accent colour while transcribing. Click to start or stop recording. The
  tooltip shows the current state, and warns you if the dictation service stops
  answering.
- **Caffeine**: a mug that's lit while the screen is kept awake. Click it to keep the
  machine awake, and click again to let it sleep. It also lights up on its own while
  a video plays, and the tooltip then names the player.
- **Theme**: a sun or moon, matching the current theme. Click to cycle to the next
  theme. The tooltip names the one you're on.
- **Notifications**: a bell, with a count of unread notifications. Click to turn do
  not disturb on or off. Right-click to open your notification history.
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
details), `marchyo.weather` (current conditions, click for a forecast panel), and
`marchyo.lockKeys` (shows CAPS / NUM while Caps Lock or Num Lock is on).
The full list of segment names is in the shell configuration reference.

## The Waybar bar

Without the shell, Waybar draws the top bar. It's styled as a compact, tmux-like
status line in the Jylhis colours and follows your theme when you switch.

On the left are the **marchyo** label and your workspaces, 1 to 5 always shown,
with the current one highlighted. Click a workspace to switch to it. The clock sits
in the middle as `Mon 05 Oct · 14:30`; click it for the long form with the week
number.

On the right, from left to right:

- **Tray**: click the `·` to slide the tray icons out.
- **Dictation**, when dictation is on: click to start or stop recording, right-click
  to open a live dictation status window.
- **Caffeine**: click to keep the machine awake, click again to let it sleep.
- **Notifications**: the bell; click to turn do not disturb on or off.
- **Keyboard layout**: click to switch to the next layout. The tooltip shows the
  full layout name.
- **Bluetooth** (`bt`, `bt off`, or `bt 2` for two connected devices): click to
  open the Bluetooth manager.
- **Network** (Wi-Fi name and signal, `eth`, or `offline`): click to open the Wi-Fi
  manager. The tooltip shows your address and interface.
- **Volume** (`vol 40%` or `vol mute`): scroll to change it in steps of 5%, up to
  150%. Right-click to mute or unmute. Click to open the audio mixer.
- **CPU** (`cpu 12%`): click to open btop.
- **Power profile** (`eco`, `bal`, or `perf`): click to cycle forward, right-click
  to cycle back.
- **Battery** (`bat 87%`, `chg 87%` while charging, `pwr` on power, `bat full`):
  click to open the power menu. The tooltip shows the power draw. The segment turns
  to a warning colour at 20% and a critical one at 10%.

Waybar has no panels and no Control Center, and its layout is fixed. If you want
those, turn on the Marchyo shell.
