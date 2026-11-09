# omarchy plugin compat shim (`qs.compat.Ui` / `qs.compat.Commons` / `qs.compat.Services`)

marchyo's shell has its own `qs.Ui` / `qs.Commons` API. Upstream *omarchy*
plugins are written against omarchy's "Quattro" shell host API, which is
different. This directory provides that host API under a separate QML namespace
so imported omarchy plugins run near-unmodified: only their
`import qs.Ui` / `import qs.Commons` lines are rewritten to
`qs.compat.Ui` / `qs.compat.Commons`, and bare `Color.` reads to
`CompatColor.` (plugins at bake time in `packages/marchyo-shell/package.nix`;
the vendored files below at author time with the same rules, plus
`import qs.Commons as Commons` / `Commons.Color.` to `Commons.CompatColor.`).

The rewrite rules live in `rewrite.sed`, which `packages/marchyo-shell/package.nix`
and `marchyo plugin dev` both apply, so a dev plugin is rewritten as a baked one is.
Plugins only: `o.workspaces.` (omarchy's Hyprland Lua namespace, which plugins
dispatch through `hyprctl dispatch`) becomes `marchyo.workspaces.`, the table
`modules/home/hyprland-monitor-workspaces.lua` registers.

The colour singleton is exported as `CompatColor`, not omarchy's `Color`:
Qt 6.12 added a `QtQuick` singleton named `Color`, and it wins over any
module's `Color` for every file that imports `QtQuick`, whatever the import
order. Under the old name every plugin colour read `undefined` (black).

## Provenance

Everything below is synced to **one** rev of **omacom/omarchy @ branch
`quattro`**, MIT: `6194f4606c585da8b839b87df9120b7d796afedf`. Upstream licence:
`LICENSE.omarchy`. Vendored files start with a short provenance header; apart
from that header they are byte-identical to upstream after the rewrite above.
To re-sync, check out the new rev, re-run the rewrite over the vendored list,
update the rev here, and run `just -f shell/Justfile check`.

## Contents

Verbatim (header and rewrite only):

- `Ui/` - the whole omarchy `shell/Ui` kit except `BackgroundMedia.qml`:
  BarIconButton, BarIconContent, BarIndicator, BarWidget, BorderOverlay,
  BorderSurface, Button, ButtonGroup, ConfirmDialog, CursorSurface, Dropdown,
  FilterInput, IconContentBounds, KeyboardPanel, MultiSelect, NumberField,
  OpticalGlyph, OverlayWindow, PanelActionButton, PanelController, PanelHero,
  PanelKeyCatcher, Panel, PanelSectionHeader, PanelSeparator, PanelSlider,
  PanelToolTip, PluginBarApi, PointerMoveGate, PopupCard, PopupMenuRow,
  SearchableDropdown, SizedImage, SpeedTestOverlay, TextField, Toggle,
  ToggleSwitch, WidgetButton.
- `Commons/`: `ShellIpc`, `IpcRegistry`, `Translations`, `Util`,
  `Numbers.js`, `Plural.js`, `BorderGeometry.js`.
- `Services/` (`qs.compat.Services`): the five plugin facade types
  `PluginShellApi`, `PluginAppLibraryApi`, `PluginBarStateApi`,
  `PluginBarWidgetRegistryApi`, `PluginRegistryApi`. They are callback holders;
  marchyo's `Services/PluginHost` supplies the callbacks.
- `omarchy/default/i18n/locales.json` and `omarchy/default/i18n/en/shell.json`:
  omarchy's English string catalog and locale registry, unmodified. `I18n`
  reads them through `$OMARCHY_PATH` (`<OMARCHY_PATH>/default/i18n/...`), so the
  wrapper points `OMARCHY_PATH` at this `omarchy/` directory. Only English is
  shipped.
- `plugins/speedtest`, `plugins/disk-speedtest`: omarchy's first-party panel
  plugins (`manifest.json`, `Panel.qml`) as upstream has them, *without* the
  import rewrite: the plugin build step applies it. `disk-speedtest` runs
  `omarchy-disk-speedtest`, which is not packaged; the panel shows its error
  state until it is.
- `plugins/clock` (`omarchy.clock`, bar widget with the calendar popup),
  `plugins/spacer` (`omarchy.spacer`, configurable blank space) and
  `plugins/dev-gallery` (`omarchy.dev-gallery`, the Ui component gallery
  panel), same layout and rewrite rule. `spacer` is upstream's
  `bar/widgets/Spacer.manifest.json` and `Spacer.qml`, laid out as a plugin
  directory (`manifest.json` at the root); the content is unchanged.
- `plugins/menu` (`omarchy.menu`, the command menu with its bar button),
  `plugins/emojis` (`omarchy.emojis`) and `plugins/clipboard`
  (`omarchy.clipboard`), same layout and rewrite rule. They read their data
  and helper scripts through `$OMARCHY_PATH`, so the matching upstream files
  sit under `omarchy/` at their upstream relative paths:
  `shell/plugins/emojis/emojis.json`, `shell/plugins/clipboard/capture.sh`,
  and `bin/omarchy-menu-emoji-insert`, `bin/omarchy-clipboard-paste-file`,
  `bin/omarchy-clipboard-paste-text`, `bin/omarchy-clipboard-open`. The shell
  build runs `patchShebangs` over that tree. `omarchy/default/omarchy/omarchy-menu.jsonc`
  is not upstream: it is marchyo's menu tree, empty until it is generated.
- Bar widgets `plugins/workspaces`, `active-window` and `tray`, laid out the
  same way. The workspaces layout-mode badge and the tray's drag-to-section
  stay inert: they need omarchy commands and layout config.
- `plugins/media` (service and bar widget). Without `omarchy.osd` its volume
  key summon is a no-op.
- `plugins/polkit`, which replaces role `polkit`.
- Panels `plugins/network`, `weather`, `tailscale`, `elsewhen` and `dropbox`,
  each replacing its `panel.<id>` role. Rows that call a missing `omarchy-*`
  command stay inert: network band, DNS, captive portal and details; weather
  location save; tailscale send file. `omarchy/shell/plugins/panels/dropbox/status.py`
  is upstream's helper, found through `$OMARCHY_PATH`.

Local deltas in vendored plugins:

- `plugins/dropbox`, `plugins/tailscale`: `Service.qml` starts with
  `pragma Singleton` and a new `qmldir` declares it, so the widget on each
  monitor shares one service (one set of timers and processes). `Panel.qml`
  reads it as a `dropbox`/`tailscale` property instead of creating a
  `Service {}`, and pushes `settings` (and, for tailscale, `peersWanted`, true
  while the widget on any monitor is open) through `Binding`s.

Reimplemented on marchyo's own `qs.Commons` (`Style`, `Colors`, `Theme`,
`I18n`); these carry omarchy's API, not its code:

- `Commons/Style.qml`: omarchy's `Style` surface. `space()/spaceReal()`,
  `spacing.*`, `font.*`, `bar.*`, `cornerRadius`, `gapsOut`, `easeOut`;
  `duration()` and `reduceMotion` follow marchyo's `Style.duration()` and its
  build, runtime and compositor reduce-motion switches. The control-state
  functions (`normalFillFor`, `hoverFillFor`, `selectedFillFor`, `focusFillFor`,
  `pressedFillFor`, `selectionFillFor`, `controlFill`, the `*StateColor` and
  `*BorderWidth` helpers) read marchyo's `Style.controls` map, so the caller's
  foreground and accent arguments are accepted but do not tint fills.
  `font.title`/`heading`/`display` use omarchy's ratios on marchyo's body size.
  The `spacing`, `bar.iconSize` and `bar.statusSlot` values are omarchy's
  pixel values scaled by marchyo's font scale (approximations, no shell.toml
  overrides).
- `Commons/CompatColor.qml`: omarchy's `Color` roles (`accent`, `foreground`,
  `muted`, `urgent`, `background`, `bar`, `popups`, `tooltip`, `notifications`,
  `menu`, `polkit`, `lock`, `imagePicker`) bound to Jylhis tokens in `Colors`;
  no colour values are defined here. Roles marchyo has no token for reuse the
  nearest one (for example `tooltip.border` is `borderStrong`).
- `Commons/Border.qml`: omarchy's border-spec shape (`{ color, widths,
  gradient }`), so the vendored `BorderOverlay` and `BorderGeometry.js` work
  unchanged. Surface and control specs resolve to the caller's colour and
  width, or to `Style.controls` for control states; there are no gradients or
  per-side widths, so surfaces draw with a native `Rectangle.border`.
- `Commons/I18n.qml`: `language` follows marchyo's `I18n.language`; strings
  come from omarchy's catalogs; a key they lack falls back to marchyo's
  `I18n.t`, then to the caller's text, then to the key.

## Skipped upstream files

- `Ui/BackgroundMedia.qml`: a background still/video renderer for omarchy's
  desktop background and lock screen; marchyo draws those itself.
- `services/PluginFirstPartyServiceApi.qml`, `services/PluginRegistry.qml` and
  the other omarchy services: marchyo's `PluginHost` replaces them.
- `Commons/Color.qml`, `AudioNodes`, `InputDevices`, `InputMethodState`,
  `UntypedInput`: omarchy services with no marchyo counterpart; none of the
  vendored files or the two speed-test plugins reads them.
- Plugins whose main data or action needs a missing `omarchy-*` command or
  omarchy service. Their UI improvements are ported into native code instead.
  - `bar`: `barConfig`, `mutateShellConfig`, `omarchy-toggle-bar`, `omarchy-font-set`.
  - `bar/widgets/Indicators`: every indicator needs omarchy CLIs or services.
  - `KeyboardLayout`: `InputMethodState`, `InputDevices`.
  - `Microphone`, `panels/audio`: `UntypedInput`, `AudioNodes`, `omarchy-audio-*`.
  - `SystemUpdate`: `omarchy-update-available`, `omarchy-update`.
  - `agents`: the `omarchy-agent-usage-*` collectors.
  - `panels/bluetooth`: `omarchy-bluetooth-device` carries connect and remove.
  - `panels/monitor`: `omarchy-monitor-state`, `omarchy-hyprland-monitor-*`.
  - `panels/power`: `omarchy-powerprofiles-*`, `omarchy-battery-status`.
  - `panels/wifiqr`: `omarchy-network-qr`, `omarchy-network-password`.
  - `lock`: PAM service `omarchy-lock-password` and `omarchy-system-lock`.
  - `osd`: fed by omarchy's `BrightnessKeys` service.
  - `notifications`: its DND and history UI live in the dropped bar.
  - `reminders`: `omarchy-reminder`.
  - `image-picker`: `omarchy-theme-switcher`, `omarchy-theme-set`.
  - `services/battery`: both actions are missing commands.
  - `services/idle`: `omarchy-system-lock`; hypridle owns idle.
  - `services/nightlight`, `services/remote-session`: only dropped plugins read them.
- `plugins/dock`: it needs `omarchy-dock`, `omarchy-hyprland-workspace-layout-current`
  (omarchy's floating workspace layouts) and `shell.shellConfig`, none of which
  marchyo has.

Window-based types (`KeyboardPanel`, `OverlayWindow`, `PopupCard`,
`SpeedTestOverlay`, and the speed-test panels that use them) cannot be created
without a layer-shell compositor, so the offscreen harness only compiles them.

## UI ported into native code

These native components carry UI ideas ported from the same omarchy rev (MIT,
`LICENSE.omarchy`), rewritten on marchyo's own `Ui`, `Style` and `I18n`:

- `Ui/BarItem.qml`, `Services/Tooltip.qml`: press, hover and tooltip behaviour.
- `Services/KeyboardLayout.qml`, `Commons/KeyboardLayoutModel.js`: keyboard selection.
- `Ui/BarIndicator.qml`, `Ui/IndicatorGroup.qml`, `Commons/IndicatorLayout.js`, `Bar/MicWidget.qml`: the indicator group and microphone control.
- `Panels/AudioPanel.qml`, `Commons/AudioDevices.js`: the audio panel.
- `Panels/BluetoothPanel.qml`, `Services/BluetoothState.qml`: the Bluetooth panel.
- `Panels/PowerPanel.qml`, `Commons/Battery.js`: the power panel.
- `Services/Power.qml`, `Commons/Battery.js`: the low-battery warning.
- `Panels/WifiQrPanel.qml`, `Services/WifiQr.qml`, `Commons/WifiQr.js`: the Wi-Fi QR panel.
- `Panels/DisplayPanel.qml`, `Services/Displays.qml`: the display panel.
- `Notifications/NotificationPopup.qml`, `Commons/NotificationCard.js`, `Commons/NotificationIcons.js`: the notification card.
- `Osd/Osd.qml`, `Commons/OsdModel.js`: the on-screen display.
- `Lock/LockScreen.qml`, `Commons/SessionLock.js`: lock screen input.
- `Panels/ReminderFlow.qml`, `Commons/ReminderFlow.js`: the reminder flow.
- `Panels/ImagePicker.qml`, `Panels/PickerImage.qml`: the image picker.
- `Panels/AgentsPanel.qml`, `Panels/AgentMeter.qml`, `Panels/AgentInfo.qml`: the agents panel.
