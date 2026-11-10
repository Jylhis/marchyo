# Changelog

All notable changes to marchyo are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
marchyo has no versioned releases: each release is named after its year and
month (`YYYY-MM`), and entries are grouped by that release.
Entries before 2026-11 were reconstructed from git history (first commit 2025-09-26).

## 2026-11

### Added

- `marchyo.graphics.primary` names the GPU that drives the display when `marchyo.graphics.vendors` lists more than one. Every listed vendor's drivers, firmware and VA-API packages are installed, but only the primary sets `LIBVA_DRIVER_NAME`, `VDPAU_DRIVER` and NVIDIA's GLX/GBM variables (NVIDIA VA-API only on Turing or newer), and with several vendors Hyprland renders on it first through `AQ_DRM_DEVICES` over `/dev/dri/marchyo-<vendor>` udev symlinks (matched by PCI address when the bus ID is set, else by driver), primary first. PRIME pairs NVIDIA with the primary integrated GPU, so AMD + NVIDIA and Intel + AMD + NVIDIA work, and bus IDs are checked for the `PCI:b:d:f` form. The option defaults to the only listed vendor, or on a PRIME laptop with one integrated GPU to `nvidia` in sync mode and the integrated GPU otherwise. **Breaking:** any other multi-vendor list must set it (assertion), and it must be one of `vendors`. Empty `vendors` installs no vendor drivers and sets no `LIBVA_DRIVER_NAME` instead of assuming Intel on x86_64, and `hardware.graphics.enable` follows `marchyo.desktop.enable` or any listed vendor.
- The flake exports the disko layouts as `lib.diskoLayout "<layout>" { device = ...; }` (`luks-btrfs-raid1` takes `deviceA` and `deviceB`; `lib.diskoLayouts` lists them), imported next to the re-exported `nixosModules.disko`, and the installer ISOs as `packages.x86_64-linux.iso-minimal` and `iso-graphical`, built with `just iso <variant>`. Checks evaluate every layout on a dummy disk and each ISO's `drvPath`. A new Installation guide covers the flow.
- `shell/dev/sandbox` runs the tree's shell in a nested Hyprland inside bubblewrap, as the transient user unit `marchyo-shell-sandbox`, with a private session bus, a private system bus with python-dbusmock services (UPower battery, NetworkManager Wi-Fi, BlueZ, power-profiles-daemon, logind, polkitd) and a private PipeWire null sink unless `--real` (data in `shell/dev/fixtures/NAME/system-bus.env`), private XDG dirs, side-effect tool stubs, the Adwaita icon theme and a headless 1920x1080 scale 1 `SHOT` output for `grim`; the nested window parks on `special:shell-sandbox`. `--fixture NAME` seeds the scratch config from `shell/dev/fixtures/NAME` (the default holds the generated `marchyo/` appearance and shell files; `sandbox up` evaluates `keybindings.json` and `menu.json` from the reference configuration unless the fixture ships its own). `just -f shell/Justfile dev` uses it and no longer stops the live `marchyo-shell` service (`dev-live` keeps that).
- `shell/dev/shot SURFACE` screenshots one shell surface in the sandbox (`launcher[:MODE]`, `menu[:ROUTE]`, `panel:ID`, `overview`, `screen`, or any registered surface opened by `--ipc` calls), after `--state query=|select=` and a settle wait, cropped from the composited output or, with `--grab`, the card alone; it prints the PNG path and the QML warnings since the previous shot.
- Shell dev hooks, inert unless set: `MARCHYO_SHELL_OUTPUT` pins every summoned surface to one output, `MARCHYO_SHELL_NO_MOTION=1` zeroes motion durations, and `MARCHYO_SHELL_DEV=1` enables the `dev` IPC target (`setLauncherQuery`, `launcherSelect`, `surfaces`, `grab`, `grabResult`, `settled`).
- `marchyo.defaults.email = "gmail"` or `"outlook"` registers that web app (Gmail, Outlook) in `marchyo.webapps` when web apps are enabled, without the full Google or Microsoft 365 preset.
- Command menu: `marchyo.menu.entries` (an attrset of dotted ids with icon, label, action, target, provider, aliases, description, when, checked, disabled and order) renders `~/.config/marchyo/menu.json`, merged per key with `menu.local.json` and reloaded live. The launcher gets a `menu` mode (route stack with a breadcrumb, Escape or Backspace on an empty field goes up, a typed query searches the whole subtree, guards run in one batched process per opening) with providers for apps, themes, wallpapers, fonts, power profiles and languages. `marchyo menu [route]` opens it over shell IPC (`--tui` keeps the gum menu), and `marchyo menu select|input` are a dmenu mode for scripts.
- Keybinding cheat sheet in the shell: `Super + K` opens the launcher `keys` mode, grouped by modifier plane, searching description and chord, with `Enter` running the bind. `keybindings.json` entries carry a `dispatch` field for plain dispatchers.
- Binds: `Super + Alt + Space` opens the command menu, `Super + R` the apps, and `Super + Ctrl + C` and `Super + Ctrl + Shift + X|H|T` the capture, toggle, hardware and theme menus.
- `marchyo.webapps.presets.google` adds the Google Workspace web apps (Gmail, Calendar, Drive, Docs, Sheets, Slides, Meet, Chat, Keep, Forms, Sites, Contacts and Tasks) without launch keys; an app of the same name in `apps` or `extraApps` keeps its entry.
- `marchyo plugin validate <dir>` checks a plugin checkout.
- `Super + Ctrl + Alt + G` opens the Ui gallery panel, and `marchyo doctor` warns when the generated bind table lacks it.
- Every leaf command of the `marchyo` CLI carries examples in `--help`, and a contract test fails a command without a description or examples.
- `marchyo notify` sends a notification over D-Bus with flags that match `omarchy-notification-send` (glyph, urgency, icon, timeout, replace id, image, `--transient`, `--exec`, up to three `--action` buttons with `--with`). The default application name is `marchyo-action`, which passes do-not-disturb. Click commands, buttons and glyphs are honoured only for a notification that carries a one-time token: `marchyo notify` writes `$XDG_RUNTIME_DIR/marchyo/notify-nonce/<nonce>` (private directory, checked for owner and mode) and the shell spends the nonce on first use, so a copy seen on the bus or in `busctl` cannot be replayed. An update to a notification (`-r`, or any `replaces_id` call) is vetted again and loses the command if it does not carry a fresh token. Commands run as argv arrays through `Quickshell.execDetached`, never a shell, and are never written to `notification-live.json`. The CLI applies the shell limits (no leading dash, 32 words, 4096 characters per word, no blank label) and exits 2, and global options before `notify` no longer reach the command words.
- Notifications keep their live toasts across a shell restart (`notification-live.json`, 20 second grace, critical ones stay) and do-not-disturb in `notification-quiet.json`. The `transient` hint keeps a notification out of history and the restore file, silenced rows are marked in history, and verification codes are stored in history only as a placeholder. The libraries `Security.js`, `Detect.js`, `Markup.js`, `Store.js` and `Delivery.js` are copied from omarchy into `shell/Commons/notify/`.
- `marchyo whats-new [--notify|--json|--mark-seen]` and the `marchyo-session-notices` user unit: when the packaged `NEWS` changed, one notification opens the What's new panel with the new entries and a dix summary of the last switch. `marchyo setup [--json|--welcome|--done]` and `marchyo setup fix <id>` drive a first-login checklist panel (git identity, SSH key, FIDO2, fingerprint, language, keyboard, theme, dictation) opened by a one-time welcome notification. Both panels open with `marchyo shell open whatsnew|setup`; the `panel.whatsnew` and `panel.setup` shortcuts toggle them (`Super + Ctrl + U`, `Super + Ctrl + H`). `marchyo doctor` checks the notification service and the permissions of the token directory.
- Notifications stack into decks by sender (per site for browsers) that expand on hover, identical repeats collapse with a count, clicks route to the default action, the sender's window or the first link, and detected verification codes get a Copy button. New options `marchyo.notifications.stackBySender`, `detectCodes` and `passApps`; new shell functions `actNewest`, `dismissOne` and `silence` with matching global shortcuts.
- `marchyo dictation start|stop|toggle|status` drives voxtype under a lock, and the bar indicator follows it.
- Elsewhen world clock panel (`Super + Ctrl + Alt + E`, `panel.elsewhen` shortcut): coastline map, per-city local time and offset, Open-Meteo place search and temperatures, per-city people names, 12/24 hour and C/F toggles, persisted in the shell state directory.
- Self-hiding bar indicators `marchyo.update`, `marchyo.disk` and `marchyo.health` (from `marchyo doctor --json`), a rollback button in the Power panel, and the `marchyo.shell.diskWarnPercent` option.
- `marchyo update --check` reports whether the flake lock pins a newer nixpkgs than the running system.
- `marchyo.theme.appearance.{transparency,corners,animations}`: opaque, transparent or glassy windows, theme, sharp or rounded corners, and auto, on or off animations (auto turns them off in a VM at session start). Live switches: `marchyo theme transparency|corners [--revert]` and `marchyo toggle animations`.
- Window utilities: `marchyo window pop|close-all|tiled-fullscreen` (pop-out on `Super + Alt + O`, recentred on monitor moves), `marchyo toggle fullscreen-desktop`, and an Appearance entry in `marchyo menu`.
- Theme surfaces for tmux and fcitx5 classicui: every theme dir (Jylhis pair, catalog, inline and `theme generate`) carries `tmux.conf` and `fcitx5-theme.conf`, and `marchyo theme` applies them live.
- `marchyo.tmux.enable` (default: `marchyo.development.enable`) installs a themed tmux with mouse, true colour and vi copy mode, and `tmux source-file` reloads a running server on a theme switch.
- Git and Jujutsu use the mergiraf syntax-aware merge driver by default (`programs.mergiraf`).
- `marchyo.language` and the `marchyo language [code|list]` verb: a string layer for the shell (`Commons/I18n`) and the CLI with per-key English fallback, `%N` holes, plural forms and locale number formatting. The English catalog lives in `shell/i18n/en`; it is the only one that ships.
- Captive-portal detection: `marchyo.network.connectivityCheck.{enable,uri,response,interval}` configures the NetworkManager connectivity check, the bar network icon and panel show Portal and Limited states, and `marchyo network portal` opens the sign-in window in a floating 900x760 web-app window, pauses a Tailscale exit node until online, and closes the window afterwards.
- `marchyo.power.hibernation` (enable, suspendThenHibernateDelay; the resume device is `boot.resumeDevice`) restores hibernation with suspend-then-hibernate, and `marchyo.power.lid` (onBattery, onAC, docked) sets the lid-close action. The power menus list Hibernate only when hibernation is enabled.
- Lid close with an external display turns the internal panel off and lid open turns it back on, through `marchyo monitor clamshell on|off`.
- Zhuyin (`chewing`) and Cangjie 5 (`cangjie`) input methods, an fcitx5 profile that starts in Latin with a lone Shift toggle and `imeTriggerKey` cycling layouts then engines, and per-language Noto CJK fontconfig fallback.
- `marchyo.keyboard.fnMode` (`media` or `function`) sets the top-row default through the hid_apple, hid_asus and asus_wmi module options.
- `marchyo.keyboard.backlight.enable` binds the keyboard backlight keys and Ctrl plus the display brightness keys to the new `marchyo brightness --keyboard up|down|toggle`.
- `marchyo.keyboard.composeKey = "shift-caps"` makes Shift+Caps Lock the Compose key while Caps Lock keeps its normal job (Hyprland only).
- `marchyo.graphics.nvidia.generation` derives the open kernel modules, the default driver branch of `hardware.nvidia.package` and `NVD_BACKEND` from the GPU generation, and `hardware.nvidia-container-toolkit.enable` defaults on with development containers.
- `marchyo.graphics.amd.{rocm,vaapi}`: ROCm with a `/opt/rocm/hip` link, `HSA_OVERRIDE_GFX_VERSION` and render/video groups; radeonsi VA-API.
- `marchyo.graphics.prime.integratedOnlySpecialisation` adds an `integrated-only` boot entry that turns off the NVIDIA GPU on hybrid laptops.
- `marchyo.performance.kyber.enable` (default on) sets the kyber I/O scheduler on whole non-rotational disks; with `tuning.nvme.enable`, NVMe disks keep mq-deadline.
- `marchyo.security.sudo.timestampTimeout` (default 10 minutes) sets `Defaults timestamp_timeout`.
- `marchyo.security.ssh` runs a key-only OpenSSH server (no password, keyboard-interactive or root login), and evaluation fails while a wheel or listed login user has no authorized key, unless sshd uses a user CA or an `AuthorizedKeysCommand`.
- `marchyo.webapps.presets.m365` and `marchyo.webapps.presets.notion` add Microsoft 365 web apps and Notion, which installs the native Linux app when unfree packages are allowed.
- Home Manager profile installs split `doc` and `devdoc` outputs, so HTML documentation from packages such as Python is available under the profile.
- The shell registers Hyprland global shortcuts (`marchyo:<name>`, listed in `shell/shortcuts.json`), and `hlua.global` in `lib/hyprland-lua.nix` binds them.
- `marchyo.hardware.camera.waitForAccess` (on with the desktop): WirePlumber waits at login until camera media devices are accessible.
- `marchyo.workspaces.perMonitor` (default on): every monitor has its own workspaces 1-10 in a block keyed by make, model and serial, ported from Omarchy's monitor-workspaces.lua. `marchyo.monitors` seeds the block order, workspaces of an unplugged monitor return when it comes back, the bar labels each monitor's workspaces 1-10, and `marchyo monitor workspaces reset` clears the cache in `$XDG_STATE_HOME/marchyo/monitors/`.
- Display panel (`Panels/DisplayPanel.qml`, `panel.display` global shortcut): one display at a time with on/off, brightness (brightnessctl, ddcutil), scale, resolution and refresh rate, a layout map to drag displays around, right-click rotation and Extend|Mirror for the built-in panel. Changes apply in one `hyprctl eval` that shifts neighbours so no displays overlap, and are saved by monitor identity (make, model, serial) to `$XDG_STATE_HOME/marchyo/monitors/settings`, which Hyprland loads after `marchyo.monitors`; the file survives rebuilds. `marchyo.monitorPanel.persist = false` stops loading it. `marchyo monitor reset` deletes it and `marchyo monitor save --nix` prints the current layout as a `marchyo.monitors` snippet.
- Shell Ui kit in `shell/Ui`, written on the Jylhis tokens: `Button`, `ButtonGroup`, `Toggle`, `TextField`, `FilterInput`, `Dropdown`, `SearchableDropdown`, `ConfirmDialog`, `PanelHero`, `PanelSectionHeader`, `PanelSeparator`, `PanelActionButton`, `PopupCard`, `PopupMenuRow` and `PointerMoveGate`. `Commons/Style` carries the control states (normal, hover, focus, selected, pressed) as fill colour, fill alpha and border, generated from the Jylhis border tokens.
- Shell panels follow one keyboard contract: a panel opened by a key or IPC takes on-demand keyboard focus, Escape closes it, Up, Down and Tab move along the controls, Enter and Space activate, and hover is ignored while the keyboard drives. `Ui/Panel` exposes an overridable `keyboardFocus`.
- `marchyo shell gallery [section]` opens a dev gallery panel (`panel.gallery` shortcut) with every Ui control in every state.
- `marchyo toggle reduce-motion` sets every shell transition to 0 ms at run time; `Style.duration()` also returns 0 while Hyprland's `animations:enabled` is off, probed at start and on each config reload. `tests/shell/motion-budget-test.js` fails on a bare animation duration or one over the longest Jylhis motion token.
- Theme and wallpaper pickers: panels `themes` (`Super + Ctrl + T`) and `backgrounds` (`Super + Ctrl + Shift + W`) show a grid with a large preview, filter-as-you-type and keyboard navigation (`marchyo shell toggle themes|backgrounds`). Wallpaper thumbnails are cached in `$XDG_CACHE_HOME/marchyo/thumbs`, keyed by size and mtime. Every theme dir carries a `wallpapers/` dir fed by the new `marchyo.theme.themes.[].wallpapers`; a theme without a preview image gets a plain tile.
- `marchyo-wallpapers` draws four patterns per polarity (grid, dots, bands, contour: `jylhis-<pattern>-{light,dark}.png`) and `passthru.forPolarity`; `marchyo bg list` prints the selectable wallpapers (the theme's, the package's for the theme's polarity, `~/Pictures/Wallpapers`) and `bg next` cycles that list.
- `marchyo font list --kind mono|ui|all` and `marchyo font set <family> --kind mono|ui|all`: the UI font sets the GTK `font-name` and the shell font. A `>font` launcher mode lists fonts.
- Appearance controls: `marchyo.theme.appearance.gaps`, `marchyo theme gaps [on|off] [--apply|--revert]`, `marchyo theme bar-position top|bottom`, `marchyo theme bar-background opaque|glassy|clear` and `marchyo theme icons [name]`, in an Appearance section of the Control Center. The CLI writes `$XDG_STATE_HOME/marchyo/shell/style.json` (`reduceMotion`, `uiFont`, `barPosition`, `barBackground`), which the shell watches. `marchyo toggle reduce-motion` takes `--apply` and persists `marchyo.theme.appearance.reduceMotion`.
- Theme surfaces for btop, kitty, foot, alacritty, Helix, Neovim and Emacs: every theme dir (Jylhis pair, catalog, inline and `theme generate`) carries `btop.theme`, `kitty.conf`, `foot-theme.ini`, `alacritty-theme.toml`, `helix-theme.toml`, `nvim-theme.lua` and `emacs-theme.el`, and `marchyo theme` links or reloads them live.
- Bar layout: `marchyo.shell.settings.bar.layout.{centerBegin,centerEnd}` flank the `center` section, which stays at the middle of the bar while they grow outwards. The default layout groups the recording, reminder, dictation, stay-awake and do-not-disturb indicators into one cluster. The tray takes `settings.pinned` (tray ids or titles) to keep icons on the bar and fold the rest behind the `·` drawer.
- `marchyo bar put|move|remove|set|list|reset|background|position` edits the bar live: the ops are kept in `$XDG_STATE_HOME/marchyo/shell/bar-layout.json`, applied by the shell over the generated `shell.json` layout, and replayed by `marchyo runtime restore`. Double-clicking empty bar space steps the bar background.
- Bar style: the Jylhis spacing scale as `Style.space()`, a hover hairline and a keyboard focus ring on bar items, and the heading ink for bar text while the bar background is see-through.
- Panels: Bluetooth (`Super + Ctrl + B`, `panel.bluetooth`, on `Services/BluetoothState`), speed test (`Super + Ctrl + Alt + P`, `panel.speedtest`: curl against Cloudflare for latency, download and upload, and a dd write and read in the cache directory) and Dropbox (`Super + Ctrl + Alt + D`, `panel.dropbox`: `dropbox status`, start and stop; it reports a missing `dropbox` command). `marchyo shell toggle bluetooth|speedtest|dropbox` opens them.
- The Display panel's layout tiles take Tab focus, Shift+arrows to move and R to rotate.
- Low-battery warning: while discharging at or below `marchyo.shell.settings.battery.lowThreshold` percent (default 10), the shell sends one critical `marchyo notify`. Charging or a level above the threshold re-arms it, and the sent flag survives a shell reload.
- Reminder flow: a click on the reminders indicator opens a two-step prompt (minutes, then an optional message) that schedules through `marchyo reminder set`. Invalid minutes raise a `marchyo notify` error.

### Changed

- **Breaking:** the pre-Omarchy-4.5 marchyo layout is the only Hyprland bind layout, and `marchyo.keyboard.legacyBinds` is removed (setting it fails evaluation with a hint). `Super + L` locks, apps sit on plain `Super + letter`, the panels on `Super + Shift` (`V` audio, `N` network, `B` power, `M` system monitor, `Q` Control Center), the overview on `Super + grave`, the command menu on `Super + Alt + Space` and the emoji picker on `Super + period`. Binds that only the 4.5 layout had get these chords: cycle the workspace layout `Super + Ctrl + J` (back `Super + Ctrl + Shift + J`), minimize to the drawer `Super + Alt + D`, calculator (qalc) `Super + Alt + C`, activity (btop) `Super + Alt + T`, next background `Super + Ctrl + Space`, toggle menu `Super + Ctrl + Shift + X`, and act on the newest notification `Super + Ctrl + Alt + comma`. The duplicate 4.5 binds go. Dictation toggles on `Super + Ctrl + X`, and `marchyo.keyboard.composeKey` defaults to `"menu"` (the Menu key; `"shift-caps"` makes Shift+Caps Lock the Compose key), so the default GitHub web app keeps `Super + Shift + G` without a clash warning.
- **Breaking:** options that only forwarded to an upstream option are retired in `modules/nixos/options/removed.nix`. Renamed, with a warning: `marchyo.security.firewall.enable` to `networking.firewall.enable`, `marchyo.power.hibernation.resumeDevice` to `boot.resumeDevice`, `marchyo.hardware.logitech.enable` to `programs.solaar.enable` (which turns on `hardware.logitech.wireless`), `marchyo.graphics.nvidia.open` to `hardware.nvidia.open`, `marchyo.graphics.nvidia.powerManagement` to `hardware.nvidia.powerManagement.enable`, `marchyo.graphics.nvidia.containerToolkit.enable` to `hardware.nvidia-container-toolkit.enable`, `marchyo.graphics.amd.overdrive.enable` to `hardware.amdgpu.overdrive.enable`, `marchyo.nix.router.{enable,port,netrcFile}` to `services.ncro.{enable,port,netrcFile}`, `marchyo.services.tailscale.enable` to `services.tailscale.enable` and `marchyo.services.localsend.{enable,openFirewall}` to `programs.localsend.{enable,openFirewall}`. Removed, failing evaluation with a hint: `marchyo.graphics.nvidia.package` (set `hardware.nvidia.package`), `marchyo.performance.kernel` (`boot.kernelPackages`), `marchyo.nix.caches` (`nix.settings.substituters` and `trusted-public-keys`), `marchyo.nix.router.extraUpstreams`, and `marchyo.users.<name>.uid` and `.name` (an assertion each). marchyo's own defaults now sit on the upstream options at `lib.mkDefault`.
- The binary cache list is `modules/nixos/caches.json`, a plain list definition, so a host's substituters and keys merge with it; ncro's upstreams are derived from `nix.settings.substituters`.
- **Breaking:** Home Manager modules read `osConfig.marchyo` directly, with no `or` fallbacks, and run only under the marchyo NixOS module, which imports them for every `marchyo.users` entry. There is no standalone Home Manager output any more: `homeConfigurations`, `lib.mkHomeConfiguration`, `mockOsConfig` and `just build-home` are gone. `homeManagerModules` stays exported.
- The bash aliases, zoxide, nh and git (gitFull with LFS) are configured in Home Manager only, instead of in both NixOS and Home Manager from `modules/generic`; trippy and the fontconfig role mapping stay at system level. The `inputs` `extraSpecialArgs` is gone.
- The design system 6.0 is vendored in `lib/design` (palette and font readers, the DTCG token files, GTK stylesheets, the starship preset, the Emacs entry points and generated Ghostty, bat and Emacs theme snapshots) and replaces the `jylhis-design` flake input; `pkgs.jylhis-design-src` points at it.
- Flake inputs are nixpkgs (nixos-unstable), home-manager, treefmt-nix, ncro, tinted-schemes and disko, each following the root nixpkgs; `default.nix` and flake-compat are gone. `nixConfig` lists the jylhis, jylhis-extra and nix-community caches.
- Only Linux systems are supported (`lib/systems.nix`), and `lib.inputsFor` is gone.
- Defaults: the bar is a full-width strip (`marchyo.theme.appearance.floatingBar = false`), the systemd-boot menu is hidden (`boot.loader.timeout = 0`; hold Space at power-on to open it), and input starts in Latin (`marchyo.keyboard.autoActivateIME = false`, fcitx5 `ActiveByDefault`).
- Checks are named predicates over shared reference systems (`tests/lib.nix`), each evaluated once and run as one `ref-<name>` check that lists every failing predicate; negative tests run together in `eval-assertions`. Build-heavy checks (the Plymouth variants, the shell wrapper, the theme asset dirs, the `hyprland --verify-config` runs and the ISO evaluations) move to `legacyPackages.<system>.heavyChecks`, built by `just check-full` and a weekly CI job. See `tests/README.md`.
- `hyprmon` comes from nixpkgs (0.0.17) instead of the local 0.0.11 package, which is gone; marchyo no longer exports it.
- The dev shell takes its QML tooling from the shared `languages.qml` devenv module. The `qs` alias moves from `.devenv/qml-modules` to `$DEVENV_STATE/qml/modules`.
- The notification centre follows the panel keyboard contract: Up and Down walk the rows, Enter opens the row's link or the sender's window, Delete removes it. A left click on a row now opens it (it removed the row before); a right click removes it.
- Runtime theme, wallpaper, font and appearance overrides survive home-manager activations: an activation hook runs `marchyo runtime restore` (theme first, then wallpaper, fonts, appearance and toggles), best effort and never failing the activation.
- `Super + Ctrl + B` opens the Bluetooth panel; the bluetui manager moves to `Super + Ctrl + Shift + B` (without the shell it stays on `Super + Ctrl + B`).
- `Super + Ctrl + T` opens the theme picker panel instead of the launcher's theme mode. The shell no longer reads the `reduce-motion` marker file; `marchyo toggle reduce-motion` writes the shell style file.
- A web app key on a chord marchyo binds gets no bind and a warning; the cheat sheet shows number-row keycodes as digits and matches downstream binds on chord and description.
- `marchyo keybindings` lists `~/.config/marchyo/keybindings.json`, written from the bind table with a group per row, then any described bind added downstream.
- Every Hyprland bind marchyo ships comes from one table, `lib/keybinds.nix`, rendered by `modules/home/keybinds.nix`; feature modules contribute only store-path commands and keyed web apps.
- Every user-visible string in the shell (bar, panels, launcher, lock, notifications, OSD, overview, polkit) and the runtime messages, notifications and menu labels of the `marchyo` CLI go through the string layer. `tests/shell/contracts-test.sh` fails on a QML text literal that bypasses `I18n`.
- `marchyo toggle gaps` and `transparency` apply through `hyprctl eval`, since `hyprctl keyword` has no effect under the Lua config.
- `rerere.autoupdate` defaults to off, so git no longer stages replayed conflict resolutions.
- Git's `merge.conflictStyle` is `diff3` instead of `zdiff3`, as the mergiraf module sets it.
- Super+1..0 (previously Super+1..5), Super+Shift+1..0 and Super+Shift+Alt+1..0 act on the focused monitor's workspaces; Super+Tab, Super+Shift+Tab, Super+Ctrl+Tab and Super+scroll stay on the focused monitor; Super+Shift+Alt+arrows move a workspace into the target monitor's block. `marchyo.workspaces.perMonitor = false` keeps the global numbering.
- Panel, launcher, overview, bar and notification binds dispatch the shell's global shortcuts instead of spawning `marchyo shell`; the lock and terminal binds keep a direct exec.
- `marchyo logout`, `reboot` and `shutdown` close every window and wait up to 2 s for the apps in a transient user unit, then end the session or run `systemctl reboot|poweroff --no-wall`.
- Shell services are event-driven: the camera indicator scans on inotify events on `/dev/video*`, caffeine and night light are shell-owned state the CLI reports to, screen recording follows a marker file `marchyo capture record` holds, the lock-key widget re-reads on Caps Lock and Num Lock binds, and the charger rating follows power_supply uevents.
- BBR congestion control with the fq qdisc and TCP MTU probing are on by default, outside `marchyo.performance.tuning.network`.
- Dependency updates (1 commit).
- Bar items scale on press, animate colour and opacity changes, take a middle click, hide their tooltip when they disappear and warm the tooltip up once per hover run. A one-glyph compact item keeps a fixed slot, so glyph width does not move the bar.
- The keyboard layout widget skips keyboards without a layout, hides itself when only one layout is set, retries until the first reading and follows the keyboard named in a layout event.
- Bar status indicators (do not disturb, caffeine, night light, dictation, camera, microphone, screen recording, remote session) form a group: inactive ones appear dimmed while the pointer is on the bar and fold away 120 ms after it leaves, and active ones keep their place. The microphone indicator mutes on right click, steps the input volume by 5% on the wheel and opens the audio panel on middle click.
- Audio panel: output and input sliders up to 150%, microphone controls, a master mute, level meters, device glyphs, a scrolling list and MPRIS player names for streams.
- Bluetooth panel: devices grouped by state, pending connect and disconnect states, forget buttons and keyboard shortcuts, audio output switching, scans owned by the panel, state messages and a name filter.
- Power panel: an animated charge meter with state glyphs, a holding-at-limit state, a stats grid (energy, rate, charger, time left or to full) and keyboard navigation between power profiles.
- Wi-Fi QR panel: a scannable square-module code, loading and error states, a password reveal, and a pending read is cancelled when the panel closes.
- Display panel: rotation choices, placement beside the other monitors, hints, a settling animation after a change and a check that a mirror took effect.
- Notification cards pause their timeout while hovered and swap the age for a close mark, fall back from the app icon to a letter avatar, tint symbolic icons, round photos, expand long bodies, confirm a copy, lay out right to left and gate link activation.
- On-screen display: level icons, fixed icon and percentage columns, localized digits, bounded messages, a snap to the new value on a fresh open and a fade that respects reduced motion.
- Lock screen: Escape and Ctrl+U clear the password, held keys do not repeat into it, a checking state shows while PAM runs and the password dots shrink to fit.
- Image picker: thumbnails fade in over a placeholder, show an error state, unload while off screen, and the preview stays loaded for 60 seconds.

### Removed

- The omarchy plugin layer: the vendored omarchy plugins and runtime (`shell/compat/plugins`, `pkgs.marchyo-shell-plugins`, `pkgs.marchyo-omarchy-shims`), the plugin host, native-role replacement (`replaces`, `marchyo.shell.replacedRoles`), `shell/Commons/OmarchyMenu.js`, the dev loader (`marchyo plugin dev`, `marchyo.shell.devPlugins`) and bar-replacing plugins (`marchyo.shell.barPlugin`). Plugins are the bar-widget, launcher and daemon kinds again, and `shell/compat` keeps the host API for omarchy bar widgets.
- The private unix shell socket: the CLI's shell calls always go through `qs ipc`.
- The AI tooling: `marchyo.ai.agents`, `accounts`, `skills`, `crashCapture`, `herdr`, `amp` and `local` (Ollama), `marchyo.console`, `marchyo agent`, `marchyo dev init|db`, the agents panel, bar widget and usage meter, `pkgs.marchyo-agent-skills` and the llm-agents overlay block. `marchyo.defaults.aiAgent` with `marchyo.development.enable` still installs one agent CLI and sets `$AI_AGENT`.
- Unfree and unverified packages and niche features: superwhisper, hex-dictation, amp-desktop, gliff (with its remote-session bar widget), hype, signed, monologue, the speaker tuner (`marchyo.audio.tuner`, `omarchy-audio-tuner`), the Cam Link 4K relay (`marchyo.hardware.camlink`), Slack theme injection and Taildrop in `marchyo share`. Dictation is Voxtype only.
- The VS Code family, Obsidian, Slack and herdr theme surfaces and the rendered `preview.png` theme card.
- Every shell and CLI catalog except English; `marchyo.language` accepts only `"en"`.
- The site's `/os` app and the `/search/` demo page (with its `site-option-paths` check and `site-option-defaults` eval test), and the shell dev MCP server (`shell/dev/mcp`, `mcp-test`).
- nix-on-droid support (`nixOnDroidModules`, `nixOnDroidConfigurations`, `lib.mkNixOnDroidConfiguration`), the remaining nix-darwin pieces, sops-nix, and the nixos-hardware input with its `nixosModules.hardware` re-export; hosts import sops-nix and nixos-hardware profiles themselves.
- The Vicinae and noctalia inputs.
- `marchyo.defaults.browser` no longer sets `$BROWSER`. xdg-settings mapped it to the first desktop file running the browser binary (often a Chrome web app), so the browser reported it was not the default.
- `lib/hex-byte.nix` and `lib/camel-case.nix`: callers use nixpkgs `lib.fromHexString` and `lib.toCamelCase`, which give the same results on token names and two-digit hexes.
- OBS Studio and lazydocker are no longer installed, and the `SUPER + ALT + D` lazydocker bind is removed. Add the packages with `environment.systemPackages` if you want them.

### Fixed

- The greeter follows every user's theme, not only the first one's: `marchyo theme set` writes `/var/lib/marchyo/greeter/theme-<user>.json` and the greeter reads the marker of the last user who logged in. With one shared `theme.json` in the sticky marker dir, the first writer owned it and every other user's rename failed silently. A marker dir that refuses the write is now reported on stderr.
- Home Manager dry runs (`home-manager switch -n`) no longer delete theme runtime links or rebuild the fontconfig cache: those activation steps go through `run`.
- `marchyo network portal` builds its window pattern only from plain host names and IPv4 addresses, with regex syntax escaped, so a portal redirect host such as `a|.*` can no longer match and close unrelated windows.
- The screen recorder stops on SIGINT when its supervisor runs under a shell without job control, such as dash: the recorder starts with the default SIGINT and SIGQUIT dispositions.
- Fish completion descriptions escape backslashes before quotes.
- The CI lock-sync check resolves the root nixpkgs input alias in `flake.lock` instead of reading `.nodes.nixpkgs`.
- `nix fmt -- --ci` passes, qmllint with zero warnings; `Displays.qml` and `Power.qml` declared properties as Timer, Process or PersistentProperties while they held objects with extra members, which hid those members from type checks.
- A test or check name defined twice throws with both sources instead of silently replacing the first.
- `modules/nixos/network.nix` points its iwd note at `docs/gotchas.md` instead of a missing page.
- Container DNS on podman networks: `modules/nixos/containers.nix` set `dns_enable`, which podman ignores; it now sets `dns_enabled`.
- The shell no longer throws a TypeError at startup: `Services/Motion` still ran the `mkdir` for the removed reduce-motion marker file.
- Chromium, Chrome and Brave follow the runtime light/dark switch: no build-time `BrowserThemeColor` policy pins them.
- Skip the default email web app when `marchyo.defaults.email` is unset, which failed evaluation with `expected a string but found null`.
- Marchyo owns the effective runtime theme and derives the desktop preference from it. Activation restores saved selections or initializes the Nix default; packaged dconf works under the restricted activation PATH. Failed preference updates preserve the previous selection and return an error.
- The shell failed to start: the launcher declared a method named `escape`, which shadows the JavaScript global, so QML rejected `LauncherWindow`. The offscreen harness now compiles every top-level shell window.
- The shell loads again: the launcher's power provider holds its hibernation `FileView` in a property, and the offscreen harness now instantiates every launcher provider.
- `marchyo toggle nightlight` sets the temperature over `hyprctl hyprsunset` instead of starting a second hyprsunset that kept `hyprsunset.service` from starting.
- Shift+Caps compose with an option that remaps Caps Lock (`ctrl:swapcaps`, `ctrl:nocaps`, `caps:*`) is an assertion error, as its `<CAPS>` symbols turned both keys into Caps Lock.
- fcitx5 starts once, from its XDG autostart unit, not also from Hyprland.
- Shell Ui kit: the reduce-motion watch survives a fresh profile, the Elsewhen search submits on Enter, a closed searchable dropdown drops its filter focus, and ConfirmDialog restores focus on close and traps all arrow keys.
- The marchyo.org site builds again on Tailwind CSS 4 (Vite plugin instead of the v3 PostCSS setup); TypeScript stays on 6 for `astro check`.
- `marchyo-wallpapers` `passthru.light` and `passthru.dark` resolve to the realised output path instead of a dangling `placeholder`.
- fcitx5 is configured only when `marchyo.desktop.enable` is set, so headless hosts no longer get the graphical input method.
- Dead `mediaTools` list removed from `packages.nix`.
- The pre-switch update diff hook and `marchyo diff` call `dix diff`, which dix 3.0 requires.
- Ghostty loads a Ghostty-only GTK stylesheet that shrinks its tab bar font without changing the interface font of other GTK apps.
- Hyprland sets `quirks:skip_non_kms_dmabuf_formats = false`, so a monitor that reconnects on DPMS wake no longer gets Mesa clients such as Ghostty and marchyo-shell disconnected by Hyprland 0.57.0.
- Printers run driverless: USB printers are served through ipp-usb, and cups-browsed is off by default because its queues stuck at NO_DEST_FOUND while CUPS creates IPP Everywhere queues itself.

### Security

- ARP answers and announcements use only the interface's own address (`arp_ignore = 1`, `arp_announce = 2`), so a dock's Ethernet and Wi-Fi on one network keep their own routes.
- The minimal installer ISO allows key-only root SSH (`prohibit-password`, no password authentication) instead of password root login.

## 2026-10

### Added

- **Theming without rebuilds:** bat, fzf, hyprlock, console colours (via `setvtrgb`), k9s, lazygit, spotify-player and gdu now switch at runtime from per-theme directories, and `marchyo theme generate` restyles the whole desktop from a wallpaper palette. `marchyo.theme.followWallpaper` makes wallpaper changes generate a matching theme.
- **Shell palette and panels:** the launcher becomes a prefix-routed command palette (`=` maths, `>theme`, `#` windows, `!` power) with clipboard image thumbnails, a Control Center (SUPER+SHIFT+Q) offers volume and mic sliders plus tiles for Wi-Fi, Bluetooth, Tailscale, DND, caffeine, night light and power profile, and SUPER+grave opens a per-monitor workspace overview with live window previews. The bar gains camera-in-use, lock-key, clock-seconds and battery readouts, a power panel and a segmented style.
- **Shell settings, plugins and commands:** `marchyo.shell.settings` is a typed submodule with per-monitor overrides, plugins declare typed kinds (bar widget, launcher, daemon) and are pinned in a lock file, new `marchyo shell`, `volume`, `brightness` and `doctor` commands report health with `--json`, and `marchyo share` sends files to LocalSend devices on the LAN.
- Dictation discards recordings with no speech, caffeine holds automatically while a video plays, toasts can be driven from the keyboard, a `reduceMotion` option turns off animations, blur and shadows (default in VM guests), and the Trigger menu gains a speed test.

### Changed

- **Quickshell shell is the default:** `marchyo.desktop.enable` now turns on the in-house shell for bar, launcher, notifications, lock and polkit; the bar spans the screen flush with windows, with the rounded floating pill available as `floatingBar`. The greeter follows the session theme and shakes on a failed login, and the lock screen shows its card only on the focused output.
- Stylix and its flake inputs are removed: lazygit, k9s, spotify-player, Emacs, GNOME fonts and the cursor are themed directly from base16 slots, and Qt apps follow the live GTK theme.
- **Fonts and design:** the desktop moves to Fira Sans, IBM Plex Mono and Jost (after a brief Geist stage) with family names shared through `lib.fonts`, and the design system and docs site are restyled to the flat, bevelled 5.0 and 6.0 looks, gaining an Icon component, form controls, popovers, drawers, a navbar and an `elements.css` that styles plain HTML.
- Desktops run a weekly `nh clean` (ten generations, 14 days) with store optimisation, hugePages tuning uses madvise-only transparent huge pages, and the power menu adds Log out, Lock + suspend, Restart shell and Reboot to firmware.
- Dependency updates (2 commits).

### Removed

- The Vicinae, noctalia, waybar, mako and SwayOSD fallbacks and the `osd` option are retired, as are the gaming, snapper and hibernation modules and the kmscon console and local Ollama modules added earlier in the month, which give way to upstream NixOS options; the cmus, neomutt and ncspot modules and the litellm gateway backend go too.
- nix-darwin support is removed, including `mkDarwinSystem`, the darwin modules and the wallpapper package.

### Fixed

- The audio panel no longer flickers, bar widgets no longer vanish, windows no longer tile under the bar and Qt 6.12 no longer turns shell colours black; runtime theme switches no longer break the next Home Manager activation, and Bluetooth enables the ISO socket experiment for LE Audio.

### Security

- The ncro cache proxy listens on 127.0.0.1 only, and the CLI moves to zod 4 and the site to current Astro, Starlight and wrangler, clearing the remaining scanner findings.

## 2026-09

### Added

- **Quickshell shell grows up:** a native session lock with in-process PAM, a greeter that replaces tuigreet under cage, an in-shell launcher with fuzzy app search, emoji picker and clipboard history, and a notification centre (SUPER+N) with persistent history and `marchyo.notifications.rules`. With the shell on, idle, sleep and SUPER+L use its lock and SUPER+R opens its launcher.
- Bar widgets for media, wireless peripheral battery, microphone use, weather, Tailscale, reminders, screen recording, night light and the active window, with panels for weather, Tailscale, Wi-Fi sharing by QR code and per-application audio streams with live peak meters.
- **Live themes:** `marchyo theme set` and `next` restyle GTK and the dconf scheme live from runtime theme directories, `marchyo theme generate` builds a palette from a wallpaper through matugen, and `marchyo.theme.appearance` scales corner radius, animation speed and border contrast.
- **Shell plugins:** a `qs.compat` shim runs upstream omarchy Quickshell plugins nearly unmodified, managed with `marchyo plugin add`, `list` and `remove`.
- `marchyo.monitors` declares monitor layout as typed data, `marchyo.defaults.excludePackages` trims default bundles, opt-in gaming (Steam, Gamescope), ddcutil and fwupd modules arrive, dictation gains jargon replacements and spoken punctuation, and Hyprland hides the cursor while typing.
- An on-demand security suite adds a lynis hardening VM test, an SBOM app and a vulnerability scan, and the ncro cache router fronts the binary caches.

### Changed

- marchyo adopts the single-theme jylhis-design 3.0.0 (`jylhis-dark` and `jylhis-light`), and scheme YAML comes from a fetched flake input so evaluation no longer forces a build.
- Development tools default to rootless Podman with Docker CLI compatibility, and desktop-only modules gate on `marchyo.desktop.enable` with `mkDefault` service defaults.
- The jotain Emacs integration is dropped, so the default editor is plain Emacs with `emacsclient` as `EDITOR` and `VISUAL`.
- Dependency updates (1 commit).

### Removed

- The `marchyo.ai` namespace (OpenRouter settings, per-user AI tooling, MCP wiring), the `llm-agents` input, the `openviking` and `pi` packages, and the vendored worktrunk module in favour of Home Manager's `programs.worktrunk`.

### Fixed

- Shell fixes: greeter and launcher crash loops, a black login screen, caffeine indicator flicker, per-monitor duplicate probes and the network widget's IP address; runtime theme colours reach Hyprland through `hl.config`, since `hyprctl keyword` did nothing under the Lua parser.
- Snapshot limits no longer prune daily snapshots, disko layouts require an explicit target device, light-variant rebuilds no longer hit dconf conflicts, and gaming no longer breaks aarch64 evaluation.

## 2026-08

### Added

- **Quickshell shell:** an opt-in `marchyo.shell` top bar themed from the Jylhis tokens reaches waybar parity (workspaces, tray, audio, battery, network, Bluetooth, CPU, caffeine, DND and dictation widgets with tooltips and tray menus). Enabling it retires waybar, SwayOSD and mako: the shell draws its own volume and brightness overlay, owns notifications and opens panels for audio, network, battery and system monitoring.
- A caffeine keep-awake toggle sits on SUPER+CTRL+K with a bar indicator.
- An end-user manual with fifteen chapters is published under `/manual` on the documentation site.

### Changed

- Hyprland settings move from hyprlang to the Lua renderer, reshaping binds, window rules and startup hooks.

### Removed

- The self-tracking telemetry stack (auditd, Vector, ActivityWatch, atuin, WakaTime) and its `marchyo.tracking` options, plus aichat, the Kitty and Xournal++ modules and the zeal docs browser.
- Bash is the only configured login shell, with the zsh and fish integrations removed, and the deprecated `marchyo.inputMethod` options are gone, so setting them is an error.

### Fixed

- Hyprland no longer exports an unexpanded `XDG_DATA_DIRS` literal that hid most applications from the launcher, and the `marchyo-shell` service no longer crash-loops on startup.
- aerc headers are readable in the light theme, desktop journal warnings are silenced, wf-recorder builds against ffmpeg 8, and the docs search page clears stale results.

### Security

- Users are no longer added to the root-equivalent docker group by default; `containers.backend` and `dockerGroup` make it an explicit opt-in.

## 2026-07

### Added

- **marchyo CLI:** a Bun-built `marchyo` CLI (status, theme, rebuild, update, rollback, gc, diff, debug) and the `marchyoctl` developer CLI are introduced, then reach 1.0 with a frozen command surface, snapshot tests, completions and a man page.
- A runtime-first change engine lets `marchyo theme`, `toggle`, `capture`, `menu`, `launch`, `monitor`, `reminder`, `font`, `install`, `remove` and `security enroll` act on the running desktop and restore overrides at startup, replacing the earlier shell scripts.
- **Omarchy-style desktop:** a central menu (SUPER+ALT+Space), a power menu, a terminal screensaver, do-not-disturb with a bar indicator, web apps with launch keys, OCR and colour-picker screenshots, universal copy and paste binds, and a dark/light theme toggle.
- Opt-in push-to-talk dictation with voxtype and Whisper (hold-to-talk on F9), Waybar recording indicator and GPU or CPU builds.
- Service and hardware options: `marchyo.power.hibernation`, `marchyo.security.fingerprint` and `fido2`, and `marchyo.bees` deduplication.
- A static Astro and Starlight documentation site replaces the Mintlify pages, with a man-page landing page, a paper and roast theme toggle, and package and option search backed by a Cloudflare D1 index.
- `marchyo.theme.themes` defines runtime-switchable themes and `marchyo.theme.fontScale` (default 1.25x) scales every text surface.

### Changed

- **Jylhis Design System v2:** cool grounds, bronze accent, Zilla Slab, Hanken Grotesk and Plex Mono across generated targets, with variants renamed Field and Sheet and an animated Plymouth splash.
- Bash becomes the default login shell on every platform, screenshot binds move to Super+S, the scratchpad to Super+D, and Waybar clicks open floating popups.
- Dependency updates (3 commits).

### Removed

- The GitHub Pages docs workflow and the `docs`, `docs-options` and `docs-lib` package outputs, a breaking change for consumers.

### Fixed

- The crash-prone iwd Wi-Fi backend gives way to NetworkManager's default, the starship prompt renders on bash again, and the jotain daemon opens GUI frames from a cold start.

## 2026-06

### Added

- Opt-in `marchyo.performance.tuning` (BBR, NVMe scheduling, dirty pages, huge pages) and a two-disk btrfs RAID1 disko template over per-device LUKS2.
- The `lib.mkNixosSystem` builder.
- Token-derived wallpapers, a searchable keybinding cheat sheet (SUPER+K), hardened SSH defaults and trash-cli.

### Changed

- Terminal tools replace GUI defaults (btop, qalc, yazi, spotify-player, aerc), and the Hyprland desktop takes a tmux-style look with square corners and flat panes.
- Jotain Emacs becomes the real default editor, and Wayland modules apply only on Linux with desktop enabled.
- Dependency updates (2 commits).

### Fixed

- Mako runs as the notification daemon again, and enabled users join the onepassword group.

### Security

- Screenshot and tracking privacy filters are hardened, password managers are skipped regardless of case, and disabled users lose trusted and docker access.

## 2026-05

### Added

- A `marchyo.emacs` namespace runs a PGTK daemon with Hyprland focus movement, a scratchpad frame and org-capture binds.
- Laurel audit logging to Vector and Loki, per-editor WakaTime options, and opt-in Solaar and Slack modules.
- fzf file and directory widgets with previews, zoxide in place of cd, and delta as the git pager.

### Changed

- Theming moves to the Jylhis Design System, with a shared palette helper driving the console, Ghostty, mako, GTK and fzf, and Literata and JetBrains Mono fonts.
- The default keyboard layout becomes us(altgr-intl) with Compose on the Menu key, and modules, options and tests are auto-discovered from their directories.
- Nixpkgs and home-manager are pinned to the 26.05 release branches.

### Removed

- The Starship prompt module and the wofi launcher module.

### Fixed

- Hyprland config tracks removed options.

## 2026-04

### Added

- Opt-in `marchyo.tracking`: local-first activity collectors for shell, desktop, editor, git and system, aggregated into a weekly analysis report with optional local LLM insights, plus atuin, ActivityWatch and WakaTime wiring.
- A generated documentation site of module option and library function references, and aarch64 NixOS configurations.
- A shared zsh configuration with completion and history search.

### Changed

- Ghostty replaces kitty as the default terminal.
- Nix logic moves into `default.nix`, `overlay.nix` and `treefmt.nix` with a `Justfile` for common tasks.
- Dependency updates (1 commit).

### Removed

- The worktrunk module, whose import-from-derivation broke cross-architecture evaluation.

### Fixed

- Ghostty alt+1 to alt+9 tab bindings work on Linux GTK, and tracking analysis uses UTC and no longer double-counts active time.
- Chrome and Spotify defaults fall back sensibly on non-x86_64 Linux.

## 2026-03

### Added

- `marchyo.defaults` picks browser, editors, players, file manager and email, with jotain available as an editor choice.
- `marchyo.keyboard.composeKey` and a keyboard guide, JACK audio, XDG user directories and a Mintlify documentation site.

### Changed

- Hyprland starts via UWSM with early-loaded NVIDIA modules, the desktop profile enables dconf and Nautilus support, and worktrunk is enabled only in development mode.

### Security

- CPU mitigations stay on unless `marchyo.performance.disableMitigations` is set, and `accept-flake-config` is no longer enabled.

### Fixed

- The `testNixOS` helper throws when any assertion fails, and deprecation warnings are silenced.

## 2026-02

### Added

- The worktrunk tool as a Home Manager module with a TOML `settings` option.
- A development VM app that boots a QEMU marchyo VM.

### Changed

- Git defaults gain histogram diffs, prune on fetch, autosquash and autostash, and binary caching moves to the jylhis cachix cache.
- Hyprland window rules use the new match syntax.

### Removed

- The Dropbox module, and the FlakeHub and Determinate inputs.

### Fixed

- A picosvg patch lets its tests pass with skia-pathops 0.9 and later.

## 2026-01

### Added

- GPU vendor options for Intel, AMD and NVIDIA with PRIME offload, sync and reverse-sync modes, and NVIDIA Wayland environment for Hyprland.
- Default applications and gvfs through an XDG module, plus theme and keyboard assertions and `LLM.md`, an assistant-oriented usage guide.

### Changed

- Lib and module tests evaluate purely instead of building toplevels.

### Fixed

- Mako urgency settings no longer produce an unparsable config.

## 2025-12

### Added

- aarch64-linux is included in flake systems, with platform-gated settings.

## 2025-11

### Added

- fcitx5 input method support with Waybar status, later unified under `marchyo.keyboard.layouts` with Chinese, Japanese and Korean IME support.
- A screenshot module for Hyprland, GNOME colour-scheme and GTK theme matching, and keyboard layout options.

### Changed

- fcitx5 is off by default and shares input state across windows.

### Fixed

- A Hyprland picture-in-picture rule error, the renamed libva-vdpau-driver package, Home Manager git options and the greeter command lookup.

## 2025-10

### Added

- **Option layer:** `marchyo.profile` presets (base, desktop, developer, gaming, server) with hostname and stateVersion options, `marchyo.btrfs` subvolume, compression and scrub settings, and `marchyo.firewall` port rules.
- Opt-in Prometheus and Grafana monitoring, kernel and systemd hardening and BTRFS root rollback.
- Installation tooling: minimal and graphical installer ISOs, disko layouts (UEFI, LUKS with btrfs), install scripts and workstation and minimal flake templates.
- Documentation and helper scripts: README, configuration guide, modules reference, troubleshooting guide, examples, `update.sh`, `rollback.sh` and `health-check.sh`.
- `marchyo.lib.mkNixosSystem`, a colourscheme system built on nix-colors Base16 and the Modus schemes, and a btop module.
- Cachix, SSH, virtualization, tmux, git-advanced, Neovim and VS Code modules, a first-boot welcome, a hyprmon monitor TUI, and a Waybar language indicator for the Hyprland keyboard layout.

### Changed

- Legacy base, desktop and developer profiles are removed, and desktop and development settings follow their enable options.
- Locale and timezone come from marchyo options, firmware is enabled by default, and the workstation template builds through `mkNixosSystem`.
- Neovim moves from nixvim to plain `programs.neovim`, and Home Manager backs up overwritten files with a `.backup` extension.
- Dependency updates (1 commit).

### Removed

- The 1Password shell plugins input, iwd Wi-Fi backend and impala TUI, and the flake-parts module layer.

### Fixed

- Waybar no longer spawns duplicate instances after sleep, and home modules apply their colour theme unconditionally.

## 2025-09

### Added

- The first NixOS and Home Manager module set for a Hyprland desktop: Waybar, kitty, Ghostty, hyprlock, mako, wofi, fonts, audio and graphics.
- A Marchyo Plymouth boot splash, CUPS printing, a hyprpaper wallpaper module and Home Manager git and shell modules.
- `marchyo.*` options for users plus desktop, development, media and office feature flags.
- A CI workflow running `nix flake check` with Cachix pushes and FlakeHub rolling releases.

### Changed

- Inputs resolve through FlakeHub tarballs and Hyprland stops forcing Wayland backends for GDK, Qt and Electron apps.
- NetworkManager is configured to use the iwd Wi-Fi backend.
