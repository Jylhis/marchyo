# Changelog

All notable changes to marchyo are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project has no versioned releases, so entries are grouped by month.
Entries up to 2026-11 were reconstructed from git history (first commit 2025-09-26).

## [Unreleased]

### Added

- `shell/dev/mcp`, a Go MCP server (`claude mcp add marchyo-shell -- go -C shell/dev/mcp run . -root ../../..`), exposes the shell sandbox to agents: `sandbox_up|down|status`, `ipc_call`, `ipc_show`, `screenshot` (PNG plus QML warnings), `logs` and `reload`. Justfile recipe `mcp-test`.
- `shell/dev/sandbox` runs the tree's shell in a nested Hyprland inside bubblewrap, as the transient user unit `marchyo-shell-sandbox`, with a private session bus, a private system bus with python-dbusmock services (UPower battery, NetworkManager Wi-Fi, BlueZ, power-profiles-daemon, logind, polkitd) and a private PipeWire null sink unless `--real` (data in `shell/dev/fixtures/NAME/system-bus.env`), private XDG dirs, side-effect tool stubs, the Adwaita icon theme and a headless 1920x1080 scale 1 `SHOT` output for `grim`; the nested window parks on `special:shell-sandbox`. `--fixture NAME` seeds the scratch config from `shell/dev/fixtures/NAME` (the default holds the generated `marchyo/` appearance, keybindings, menu and shell files). `just -f shell/Justfile dev` uses it and no longer stops the live `marchyo-shell` service (`dev-live` keeps that).
- `shell/dev/shot SURFACE` screenshots one shell surface in the sandbox (`launcher[:MODE]`, `menu[:ROUTE]`, `panel:ID`, `overview`, `screen`, or any registered surface opened by `--ipc` calls), after `--state query=|select=` and a settle wait, cropped from the composited output or, with `--grab`, the card alone; it prints the PNG path and the QML warnings since the previous shot. Justfile recipe `shot`.
- Shell dev hooks, inert unless set: `MARCHYO_SHELL_OUTPUT` pins every summoned surface to one output, `MARCHYO_SHELL_NO_MOTION=1` zeroes motion durations, and `MARCHYO_SHELL_DEV=1` enables the `dev` IPC target (`setLauncherQuery`, `launcherSelect`, `surfaces`, `grab`, `grabResult`, `settled`).
- `marchyo.defaults.email = "gmail"` or `"outlook"` registers that web app (Gmail, Outlook) in `marchyo.webapps` when web apps are enabled, without the full Google or Microsoft 365 preset.
- Command menu: `marchyo.menu.entries` (an attrset of dotted ids with icon, label, action, target, provider, aliases, description, when, checked, disabled and order) renders `~/.config/marchyo/menu.json`, merged per key with `menu.local.json` and reloaded live. The launcher gets a `menu` mode (route stack with a breadcrumb, Escape or Backspace on an empty field goes up, a typed query searches the whole subtree, guards run in one batched process per opening) with providers for apps, themes, wallpapers, fonts, power profiles, languages and agents. `marchyo menu [route]` opens it over shell IPC (`--tui` keeps the gum menu), and `marchyo menu select|input` are a dmenu mode for scripts.
- Keybinding cheat sheet in the shell: `Super + K` opens the launcher `keys` mode, grouped by modifier plane, searching description and chord, with `Enter` running the bind. `keybindings.json` entries carry a `dispatch` field for plain dispatchers.
- Binds: `Super + Space` opens the command menu, `Super + Alt + Space` the apps, `Super + Ctrl + C|X|H` and `Super + Ctrl + Shift + T|W` the capture, toggle, hardware, theme and background menus.
- omarchy plugin host: shell plugin kinds `panel`, `menu`, `overlay`, `service` and `bar` (with `keepLoaded`, the `barWidget` block, sibling `*.manifest.json` files and the reserved `omarchy.*` and `marchyo.*` id namespaces), loaded by `Plugins/PluginLayer` through `Services/PluginHost`. The shell IPC gains `summonPlugin`, `hidePlugin`, `togglePlugin`, `callPlugin`, `togglePanelAt` and `rescanPlugins`. `shell/compat` is re-synced to one omarchy rev with the rest of the Ui kit, `Numbers`/`Plural`/`Translations`, an `I18n` over omarchy's English catalog, and the `qs.compat.Services` facades.
- `pkgs.marchyo-omarchy-shims`: `omarchy-notification-send`, `-menu-select`, `-menu-input`, `-launch-browser`, `-launch-terminal`, `-launch-floating-terminal-with-presentation`, `-default-agent`, `-cmd-present` and `-pkg-present`, beside `omarchy-shell` and `omarchy-bar`, on the shell PATH when plugins are declared. omarchy's speedtest panels are packaged as `pkgs.marchyo-shell-plugins.omarchy-speedtest` and `.omarchy-disk-speedtest`.
- `marchyo.webapps.presets.google` adds the Google Workspace web apps (Gmail, Calendar, Drive, Docs, Sheets, Slides, Meet, Chat, Keep, Forms, Sites, Contacts and Tasks) without launch keys; an app of the same name in `apps` or `extraApps` keeps its entry.
- omarchy's first-party clock, spacer and dev gallery plugins are vendored under `shell/compat/plugins` and packaged as `pkgs.marchyo-shell-plugins.omarchy-clock`, `.omarchy-spacer` and `.omarchy-dev-gallery`. The compat `Style` gains the `*BorderFor` helpers.
- omarchy's menu, emoji picker and clipboard manager plugins are vendored under `shell/compat/plugins` and packaged as `pkgs.marchyo-shell-plugins.omarchy-menu`, `.omarchy-emojis` and `.omarchy-clipboard`, with their `$OMARCHY_PATH` data and helper scripts under `shell/compat/omarchy`. `pkgs.marchyo-omarchy-shims` gains `omarchy-launch-editor`, `omasnap` and the `omarchy-font-*`, `omarchy-powerprofiles-*` and `omarchy-language` providers; the shell PATH gains the clipboard and emoji runtime tools. The plugin app library returns scored rows with `entry`, and resolves absolute and empty icons.
- `pkgs.marchyo-shell-plugins.omarchy-menu`, `.omarchy-emojis` and `.omarchy-clipboard` replace the `launcher`, `launcher.emoji` and `launcher.clipboard` roles. `Services/Launcher` sends a replaced mode to its plugin (`Commons/LauncherRoutes.js`): menu routes, apps, font and keys go to the menu as `{"menu": route}`, `marchyo menu select|input` requests become its dmenu payload answered in the same `.out` and `.done` files, emoji and clipboard summon their plugins, and the power panel's menu button opens the system route.
- While `omarchy.menu` replaces the launcher, the shell writes `marchyo.menu.entries`, merged with `menu.local.json`, as omarchy's `~/.config/omarchy/extensions/omarchy-menu.jsonc` (`shell/Commons/OmarchyMenu.js`): tree order, Nerd Font glyphs for the themed icon names, aliases as search terms, disabled entries left out, the themes, wallpapers and agents providers as rows that open the native panels, and the keybinding cheat sheet as the `keys` submenu.
- omarchy's workspaces, active window, tray, media, polkit, network, weather, tailscale, elsewhen and dropbox plugins are vendored under `shell/compat/plugins` and packaged in `pkgs.marchyo-shell-plugins`; `shell/compat/README.md` lists the omarchy plugins that cannot run and why.
- Shell plugins can take over a native component through `replaces` (roles in `packages/marchyo-shell/native-roles.nix`: the summonable panels, `polkit` and the launcher roles). A replaced panel's openers summon the plugin, a replaced `polkit` keeps the native agent and dialog off, and `marchyo.shell.replacedRoles` maps each role to its plugin, with an assertion against two claims on one role.
- `marchyo plugin validate <dir>` and `marchyo plugin dev <dir> [--watch|--remove]`; the dev loader is off unless `marchyo.shell.devPlugins.enable` is set. New option `marchyo.shell.barPlugin`.
- `Super + Ctrl + Alt + G` opens the Ui gallery panel, and `marchyo doctor` warns when the generated bind table lacks it.
- Agent skills `marchyo`, `marchyo-plugin` and `diagnose-crash` (`pkgs.marchyo-agent-skills`), installed into the Claude Code, Codex and opencode skill directories by `marchyo.ai.skills.enable` (default on while an AI agent is installed). `diagnose-crash` is adapted from Omarchy (MIT) for NixOS debuginfo.
- Crash capture: `marchyo.ai.crashCapture.{enable,ignore,dedupeSeconds}` runs a user service that follows systemd-coredump in the journal and sends a notification whose Diagnose action runs the new `marchyo agent crash <pid> [comm] [exe] [signal] [timestamp]` on `$AI_AGENT`. `marchyo toggle crash-capture` stops and starts it live. Only entries logged by `systemd-coredump@` count; the crash values reach the agent quoted, capped and marked as untrusted; the agent starts in its most restricted approval mode in its own transient unit; notifications are rate limited, capped and escaped; the unit is sandboxed and takes the ignore regex through a file.
- `marchyo agent usage` also reports Z.ai Coding Plan limits (`ZAI_API_KEY`) and the OpenRouter key limit (`OPENROUTER_API_KEY`).
- `marchyo dev init <lang> [--force]` writes a `devenv.nix`, `devenv.yaml` and `.envrc` for one of 15 languages into the current directory, and `marchyo dev db <engine>` adds a devenv postgres, mysql, mariadb, redis or mongodb service to an existing `devenv.nix`, idempotently. Every leaf command now carries examples in `--help`, and a contract test fails a command without a description or examples.
- `marchyo notify` sends a notification over D-Bus with flags that match `omarchy-notification-send` (glyph, urgency, icon, timeout, replace id, image, `--transient`, `--exec`, up to three `--action` buttons with `--with`). The default application name is `marchyo-action`, which passes do-not-disturb. Click commands, buttons and glyphs are honoured only for a notification that carries a one-time token: `marchyo notify` writes `$XDG_RUNTIME_DIR/marchyo/notify-nonce/<nonce>` (private directory, checked for owner and mode) and the shell spends the nonce on first use, so a copy seen on the bus or in `busctl` cannot be replayed. An update to a notification (`-r`, or any `replaces_id` call) is vetted again and loses the command if it does not carry a fresh token. Commands run as argv arrays through `Quickshell.execDetached`, never a shell, and are never written to `notification-live.json`. The CLI applies the shell limits (no leading dash, 32 words, 4096 characters per word, no blank label) and exits 2, and global options before `notify` no longer reach the command words.
- Notifications keep their live toasts across a shell restart (`notification-live.json`, 20 second grace, critical ones stay) and do-not-disturb in `notification-quiet.json`. The `transient` hint keeps a notification out of history and the restore file, silenced rows are marked in history, and verification codes are stored in history only as a placeholder. The libraries `Security.js`, `Detect.js`, `Markup.js`, `Store.js` and `Delivery.js` are copied from omarchy into `shell/Commons/notify/`.
- `marchyo whats-new [--notify|--json|--mark-seen]` and the `marchyo-session-notices` user unit: when the packaged `NEWS` changed, one notification opens the What's new panel with the new entries and a dix summary of the last switch. `marchyo setup [--json|--welcome|--done]` and `marchyo setup fix <id>` drive a first-login checklist panel (git identity, SSH key, FIDO2, fingerprint, language, keyboard, theme, agent login, dictation) opened by a one-time welcome notification. Both panels open with `marchyo shell open whatsnew|setup`; the `panel.whatsnew` and `panel.setup` shortcuts toggle them (`Super + Ctrl + U`, `Super + Ctrl + H`). `marchyo doctor` checks the notification service and the permissions of the token directory.
- Notifications stack into decks by sender (per site for browsers) that expand on hover, identical repeats collapse with a count, clicks route to the default action, the sender's window or the first link, and detected verification codes get a Copy button. New options `marchyo.notifications.stackBySender`, `detectCodes` and `passApps`; new shell functions `actNewest`, `dismissOne` and `silence` with matching global shortcuts.
- `marchyo dictation start|stop|toggle|status` drives the configured dictation backend under a lock; F9 hold is a Hyprland press/release pair on the Superwhisper and Hex backends. The bar indicator works with every backend.
- Elsewhen world clock panel (`Super + Ctrl + Alt + E`, `panel.elsewhen` shortcut): coastline map, per-city local time and offset, Open-Meteo place search and temperatures, per-city people names, 12/24 hour and C/F toggles, persisted in the shell state directory.
- Self-hiding bar indicators `marchyo.remoteSession` (gliff session with peer address), `marchyo.update`, `marchyo.disk` and `marchyo.health` (from `marchyo doctor --json`), a rollback button in the Power panel, and the `marchyo.shell.diskWarnPercent` option.
- `marchyo update --check` reports whether the flake lock pins a newer nixpkgs than the running system.
- `marchyo.theme.appearance.{transparency,corners,animations}`: opaque, transparent or glassy windows, theme, sharp or rounded corners, and auto, on or off animations (auto turns them off in a VM at session start). Live switches: `marchyo theme transparency|corners [--revert]` and `marchyo toggle animations`.
- Window utilities: `marchyo window pop|close-all|tiled-fullscreen` (pop-out on `Super + Alt + O`, recentred on monitor moves), `marchyo toggle fullscreen-desktop`, and an Appearance entry in `marchyo menu`.
- Theme surfaces for VS Code (and Insiders, VSCodium, Cursor), Obsidian, tmux, Slack, fcitx5 classicui and herdr: every theme dir (Jylhis pair, catalog, inline and `theme generate`) carries `vscode-theme.json`, `obsidian.css`, `tmux.conf`, `slack.json`, `fcitx5-theme.conf` and `herdr.json`, and `marchyo theme` applies them live.
- `marchyo.tmux.enable` (default: `marchyo.development.enable`) installs a themed tmux with mouse, true colour and vi copy mode, and `tmux source-file` reloads a running server on a theme switch.
- `marchyo.slack.themeInjection.enable` (default off) starts Slack through `marchyo-slack`, a launcher adapted from Omarchy that applies the theme through Chromium's remote-debugging pipe.
- Git and Jujutsu use the mergiraf syntax-aware merge driver by default (`programs.mergiraf`).
- `marchyo.language` and the `marchyo language [code|list]` verb: a string layer for the shell (`Commons/I18n`) and the CLI with per-key English fallback, `%N` holes, plural forms and locale number formatting. Catalogs live in `shell/i18n` and seed from Omarchy's registry; the Audio and Power panels use it.
- Captive-portal detection: `marchyo.network.connectivityCheck.{enable,uri,response,interval}` configures the NetworkManager connectivity check, the bar network icon and panel show Portal and Limited states, and `marchyo network portal` opens the sign-in window in a floating 900x760 web-app window, pauses a Tailscale exit node until online, and closes the window afterwards.
- `marchyo.power.hibernation` (enable, resumeDevice, suspendThenHibernateDelay) restores hibernation with suspend-then-hibernate, and `marchyo.power.lid` (onBattery, onAC, docked) sets the lid-close action. The power menus list Hibernate only when hibernation is enabled.
- Lid close with an external display turns the internal panel off and lid open turns it back on, through `marchyo monitor clamshell on|off`.
- Zhuyin (`chewing`) and Cangjie 5 (`cangjie`) input methods, an fcitx5 profile that starts in Latin with a lone Shift toggle and `imeTriggerKey` cycling layouts then engines, and per-language Noto CJK fontconfig fallback.
- `marchyo.keyboard.fnMode` (`media` or `function`) sets the top-row default through the hid_apple, hid_asus and asus_wmi module options.
- `marchyo.keyboard.backlight.enable` binds the keyboard backlight keys and Ctrl plus the display brightness keys to the new `marchyo brightness --keyboard up|down|toggle`.
- `marchyo.keyboard.composeKey = "shift-caps"` makes Shift+Caps Lock the Compose key while Caps Lock keeps its normal job (Hyprland only).
- `marchyo.graphics.nvidia.{generation,package,containerToolkit.enable}`: pick the driver branch (`stable`, `beta`, `production`, `legacy_580`), derive open modules and `NVD_BACKEND` from the GPU generation, and enable the NVIDIA Container Toolkit by default with development containers.
- `marchyo.graphics.amd.{rocm,vaapi,overdrive}`: ROCm with a `/opt/rocm/hip` link, `HSA_OVERRIDE_GFX_VERSION` and render/video groups; radeonsi VA-API; amdgpu overdrive.
- `marchyo.graphics.prime.integratedOnlySpecialisation` adds an `integrated-only` boot entry that turns off the NVIDIA GPU on hybrid laptops.
- `marchyo.ai.local.{enable,models,host,port,acceleration}` runs Ollama with the CUDA, ROCm or default build chosen from `marchyo.graphics`, and adds an `ollama` provider to opencode when it is the default AI agent.
- `marchyo.performance.kyber.enable` (default on) sets the kyber I/O scheduler on whole non-rotational disks; with `tuning.nvme.enable`, NVMe disks keep mq-deadline.
- `marchyo.security.sudo.timestampTimeout` (default 10 minutes) sets `Defaults timestamp_timeout`.
- `marchyo.security.ssh` runs a key-only OpenSSH server (no password, keyboard-interactive or root login), and evaluation fails while a wheel or listed login user has no authorized key, unless sshd uses a user CA or an `AuthorizedKeysCommand`.
- `marchyo.webapps.presets.m365` and `marchyo.webapps.presets.notion` add Microsoft 365 web apps and Notion, which installs the native Linux app when unfree packages are allowed.
- Fleet and options UI at marchyo.org/os, with local browser storage and Nix configuration export.
- Home Manager profile installs split `doc` and `devdoc` outputs, so HTML documentation from packages such as Python is available under the profile. ([f719ddd26a](https://github.com/Jylhis/j10s/commit/f719ddd26a))
- The shell registers Hyprland global shortcuts (`marchyo:<name>`, listed in `shell/shortcuts.json`), and `hlua.global` in `lib/hyprland-lua.nix` binds them.
- The shell listens on a private unix socket (`$XDG_RUNTIME_DIR/marchyo-shell-<id>.sock`), and the CLI's shell calls use it before `qs ipc`.
- Packages `hype`, `signed`, `monologue`, `gliff` (x86_64 only), `omarchy-audio-tuner`, `hex-dictation` (Hex voice dictation), and the unfree binaries `superwhisper` and `amp-desktop`.
- `marchyo.audio.tuner.{enable,profile}`: installs `omarchy-audio-tuner` and applies a shipped speaker tuning (`dell-xps-2026`, `asus-proart-p14-n1x`, `asus-zenbook-a16-ux3607oa`) as a PipeWire filter-chain hosted by the `marchyo-speaker-tuning` user service.
- `marchyo.hardware.camlink.enable`: Elgato Cam Link 4K relayed through v4l2loopback and `v4l2-relayd` as a 16:9 virtual camera, started by udev on plug-in.
- `marchyo.hardware.camera.waitForAccess` (on with the desktop): WirePlumber waits at login until camera media devices are accessible.
- `marchyo share --tailscale <peer>` sends over Taildrop, `marchyo share --tailscale-receive [dir]` saves incoming files, and the share menu lists Taildrop when `tailscale` is installed.
- The overlay exposes `herdr-app`, `grok`, `opencode2`, `pi`, `t3code-desktop`, `hunk` and `amp-cli` (the Amp CLI) from llm-agents.nix.
- `marchyo.workspaces.perMonitor` (default on): every monitor has its own workspaces 1-10 in a block keyed by make, model and serial, ported from Omarchy's monitor-workspaces.lua. `marchyo.monitors` seeds the block order, workspaces of an unplugged monitor return when it comes back, the bar labels each monitor's workspaces 1-10, and `marchyo monitor workspaces reset` clears the cache in `$XDG_STATE_HOME/marchyo/monitors/`.
- Display panel (`Panels/DisplayPanel.qml`, `panel.display` global shortcut): one display at a time with on/off, brightness (brightnessctl, ddcutil), scale, resolution and refresh rate, a layout map to drag displays around, right-click rotation and Extend|Mirror for the built-in panel. Changes apply in one `hyprctl eval` that shifts neighbours so no displays overlap, and are saved by monitor identity (make, model, serial) to `$XDG_STATE_HOME/marchyo/monitors/settings`, which Hyprland loads after `marchyo.monitors`; the file survives rebuilds. `marchyo.monitorPanel.persist = false` stops loading it. `marchyo monitor reset` deletes it and `marchyo monitor save --nix` prints the current layout as a `marchyo.monitors` snippet.
- `marchyo.ai.agents` installs a list of AI coding-agent CLIs (claude-code, codex, opencode, grok, gemini, copilot); `marchyo.defaults.aiAgent` joins the list.
- `marchyo agent usage [--json] [--force]` reads Claude Code, Codex and GitHub Copilot usage limits and local transcript token totals, cached without credentials in `$XDG_STATE_HOME/marchyo/agents/usage.json`. The shell shows them in an agents panel (`panel.agents` global shortcut) and a `marchyo.agents` bar widget with the tightest limit.
- `marchyo.console.enable` (default on with the desktop): a Quake-style `special:qconsole` terminal on Super+Ctrl+grave that opens `$AI_AGENT` or a shell.
- `marchyo.ai.herdr.{enable,desktop.enable}`: herdr, a `herdr server` user service, Super+Ctrl+Return and per-agent `herdr integration install` units.
- `marchyo.ai.amp.{enable,desktop.enable}`: Amp CLI and desktop app, with an unfree assertion.
- `marchyo agent account list|add|use|remove|rename|mode|copy|import` keeps several Claude Code, Codex and Grok sign-ins. Added accounts hold only their credentials under `$XDG_STATE_HOME/marchyo/agents/accounts/<provider>/<id>/` and link history, settings, skills and sessions to `~/.claude`, `~/.codex` or `~/.grok`. `marchyo.ai.accounts.enable` (default on) installs `claude`, `codex` and `grok` wrappers that start sessions as the active account; usage limits are read per account, `auto` mode moves new sessions to the account with the most headroom at the threshold, and `manual` mode offers a one-click switch in a notification and the agents panel.
- Shell Ui kit in `shell/Ui`, written on the Jylhis tokens: `Button`, `ButtonGroup`, `Toggle`, `TextField`, `FilterInput`, `Dropdown`, `SearchableDropdown`, `ConfirmDialog`, `PanelHero`, `PanelSectionHeader`, `PanelSeparator`, `PanelActionButton`, `PopupCard`, `PopupMenuRow` and `PointerMoveGate`. `Commons/Style` carries the control states (normal, hover, focus, selected, pressed) as fill colour, fill alpha and border, generated from the Jylhis border tokens.
- Shell panels follow one keyboard contract: a panel opened by a key or IPC takes on-demand keyboard focus, Escape closes it, Up, Down and Tab move along the controls, Enter and Space activate, and hover is ignored while the keyboard drives. `Ui/Panel` exposes an overridable `keyboardFocus`.
- `marchyo shell gallery [section]` opens a dev gallery panel (`panel.gallery` shortcut) with every Ui control in every state.
- `marchyo toggle reduce-motion` sets every shell transition to 0 ms at run time; `Style.duration()` also returns 0 while Hyprland's `animations:enabled` is off, probed at start and on each config reload. `tests/shell/motion-budget-test.js` fails on a bare animation duration or one over the longest Jylhis motion token.
- Theme and wallpaper pickers: panels `themes` (`Super + Ctrl + T`) and `backgrounds` (`Super + Ctrl + Shift + W`) show a grid with a large preview, filter-as-you-type and keyboard navigation (`marchyo shell toggle themes|backgrounds`). Wallpaper thumbnails are cached in `$XDG_CACHE_HOME/marchyo/thumbs`, keyed by size and mtime. Every theme dir carries a `preview.png` palette card (480x270, rendered with resvg) and a `wallpapers/` dir fed by the new `marchyo.theme.themes.[].wallpapers`.
- `marchyo-wallpapers` draws four patterns per polarity (grid, dots, bands, contour: `jylhis-<pattern>-{light,dark}.png`) and `passthru.forPolarity`; `marchyo bg list` prints the selectable wallpapers (the theme's, the package's for the theme's polarity, `~/Pictures/Wallpapers`) and `bg next` cycles that list.
- `marchyo font list --kind mono|ui|all` and `marchyo font set <family> --kind mono|ui|all`: the UI font sets the GTK `font-name` and the shell font. A `>font` launcher mode lists fonts.
- Appearance controls: `marchyo.theme.appearance.gaps`, `marchyo theme gaps [on|off] [--apply|--revert]`, `marchyo theme bar-position top|bottom`, `marchyo theme bar-background opaque|glassy|clear` and `marchyo theme icons [name]`, in an Appearance section of the Control Center. The CLI writes `$XDG_STATE_HOME/marchyo/shell/style.json` (`reduceMotion`, `uiFont`, `barPosition`, `barBackground`), which the shell watches. `marchyo toggle reduce-motion` takes `--apply` and persists `marchyo.theme.appearance.reduceMotion`.
- Theme surfaces for btop, kitty, foot, alacritty, Helix, Neovim, Emacs and Chromium: every theme dir (Jylhis pair, catalog, inline and `theme generate`) carries `btop.theme`, `kitty.conf`, `foot-theme.ini`, `alacritty-theme.toml`, `helix-theme.toml`, `nvim-theme.lua`, `emacs-theme.el` and `chromium-policy.json`, and `marchyo theme` links or reloads them live. Chromium, Chrome and Brave get `BrowserThemeColor` from the build-time theme's background (`base00`, not the near-white Jylhis accent) through `programs.chromium.extraOpts`; the policy is root-owned, so a runtime switch does not change it.
- Bar layout: `marchyo.shell.settings.bar.layout.{centerBegin,centerEnd}` flank the `center` section, which stays at the middle of the bar while they grow outwards. The default layout groups the recording, reminder, remote session, dictation, stay-awake and do-not-disturb indicators into one cluster. The tray takes `settings.pinned` (tray ids or titles) to keep icons on the bar and fold the rest behind the `·` drawer.
- `marchyo bar put|move|remove|set|list|reset|background|position` edits the bar live: the ops are kept in `$XDG_STATE_HOME/marchyo/shell/bar-layout.json`, applied by the shell over the generated `shell.json` layout, and replayed by `marchyo runtime restore`. Double-clicking empty bar space steps the bar background.
- Bar style: the Jylhis spacing scale as `Style.space()`, a hover hairline and a keyboard focus ring on bar items, and the heading ink for bar text while the bar background is see-through.
- Panels: Bluetooth (`Super + Ctrl + B`, `panel.bluetooth`, on `Services/BluetoothState`), speed test (`Super + Ctrl + Alt + P`, `panel.speedtest`: curl against Cloudflare for latency, download and upload, and a dd write and read in the cache directory) and Dropbox (`Super + Ctrl + Alt + D`, `panel.dropbox`: `dropbox status`, start and stop; it reports a missing `dropbox` command). `marchyo shell toggle bluetooth|speedtest|dropbox` opens them.
- The AI agents panel shows a stale marker for limits older than an hour and a sign-in message for a failed check that needs a sign-in. The Display panel's layout tiles take Tab focus, Shift+arrows to move and R to rotate.
- Low-battery warning: while discharging at or below `marchyo.shell.settings.battery.lowThreshold` percent (default 10), the shell sends one critical `marchyo notify`. Charging or a level above the threshold re-arms it, and the sent flag survives a shell reload.
- Reminder flow: a click on the reminders indicator opens a two-step prompt (minutes, then an optional message) that schedules through `marchyo reminder set`. Invalid minutes raise a `marchyo notify` error.

### Changed

- The published tree vendors `lib/kit/cache-trust.nix`, which `lib/kit/r2-cache.nix` now reads for the trusted R2 cache keys.
- `hyprmon` comes from nixpkgs (0.0.17) instead of the local 0.0.11 package, which is gone; marchyo no longer exports it.
- `hyprmon` comes from nixpkgs (0.0.17) instead of the local 0.0.11 package, which is gone; marchyo no longer exports it.
- The dev shell takes its QML tooling from the shared `languages.qml` devenv module. The `qs` alias moves from `.devenv/qml-modules` to `$DEVENV_STATE/qml/modules`.
- The native launcher window loads only while a launcher role stays native, and cliphist stops capturing while a plugin replaces `launcher.clipboard`.
- The notification centre follows the panel keyboard contract: Up and Down walk the rows, Enter opens the row's link or the sender's window, Delete removes it. A left click on a row now opens it (it removed the row before); a right click removes it.
- Runtime theme, wallpaper, font and appearance overrides survive home-manager activations: an activation hook runs `marchyo runtime restore` (theme first, then wallpaper, fonts, appearance and toggles), best effort and never failing the activation.
- `Super + Ctrl + B` opens the Bluetooth panel; the bluetui manager moves to `Super + Ctrl + Shift + B` (without the shell it stays on `Super + Ctrl + B`).
- `Super + Ctrl + T` opens the theme picker panel instead of the launcher's theme mode. The shell no longer reads the `reduce-motion` marker file; `marchyo toggle reduce-motion` writes the shell style file.
- A web app key on a chord marchyo binds gets no bind and a warning; the cheat sheet shows number-row keycodes as digits and matches downstream binds on chord and description.
- **Breaking:** `marchyo.keyboard.composeKey` defaults to `"shift-caps"` (Shift+Caps Lock is Compose in Hyprland; the console and X get no compose key). Set `"menu"` for the previous default. `XKB_CONFIG_EXTRA_PATH` is also exported in the Hyprland env and `~/.config/uwsm/env-hyprland`.
- **Breaking:** the default Hyprland binds follow the Omarchy 4.5 planes (Super system, Super+Shift apps, Super+Ctrl panels and menus, Super+Ctrl+Alt quick actions). Moved: lock `Super+L` to `Super+Ctrl+L`; music `Super+M` to `Super+Shift+M`; audio, network, power, system monitor and Control Center panels `Super+Shift+V/N/B/M/Q` to `Super+Ctrl+A/N/P/M/O`; overview `Super+grave` to `Super+Ctrl+grave`; Quake console `Super+Ctrl(+Shift)+grave` to `Super(+Shift)+grave`; emoji `Super+period` to `Super+Ctrl+E`; notification dismiss-all, history, keyboard control and do-not-disturb to `Super+Shift+comma`, `Super+Shift+Alt+comma`, `Super+Ctrl+comma` and `Super+Ctrl+Alt+comma`; Emacs everywhere to `Super+Shift+Alt+E`, org capture to `Super+Ctrl+Alt+O`, Emacs-aware focus/swap to `Super+Ctrl+Alt(+Shift)+H/J/K/L`; window-to-monitor `Super+Shift+comma/period` to `Super+Shift+Ctrl+arrows`. New: `Super+L` / `Super+Alt+L` layout cycle, `Super+M` minimize to the drawer, `Super+A` select all, `Super+comma` / `Super+Alt+comma` act on / dismiss the newest notification, `Super+Shift+Q` calculator, `Super+Shift+T` activity, `Super+Ctrl+D` display panel, `Super+Shift+Ctrl+A` agents panel, `Super+Ctrl+W` next background, `Super+Ctrl+Alt+C` screenshot, `Super+Ctrl+Alt+F` full screen desktop; `Super+C/V` send Ctrl+Shift+C/V to windows tagged `terminal` (the configured terminal plus known terminal classes) and keep Ctrl/Shift+Insert elsewhere. `marchyo.keyboard.legacyBinds` restores the previous layout for one release.
- `marchyo keybindings` lists `~/.config/marchyo/keybindings.json`, written from the bind table with a group per row, then any described bind added downstream.
- Every Hyprland bind marchyo ships comes from one table, `lib/keybinds.nix`, rendered by `modules/home/keybinds.nix`; feature modules contribute only store-path commands and keyed web apps.
- Every user-visible string in the shell (bar, panels, launcher, lock, notifications, OSD, overview, polkit) and the runtime messages, notifications and menu labels of the `marchyo` CLI go through the string layer, so `marchyo language` translates them. Locales carry over the matching Omarchy translations (MIT) and fall back to English per key. `tests/shell/contracts-test.sh` fails on a QML text literal that bypasses `I18n`.
- **Breaking:** `marchyo.dictation.backend` selects the dictation engine (`superwhisper`, `voxtype` or `hex`) and defaults to `superwhisper`, which is unfree: evaluation fails unless `nixpkgs.config.allowUnfree` admits it. Set `backend = "voxtype"` for the previous behaviour. The toggle bind moves from Super+Ctrl+X to Alt+Space and runs the new `marchyo dictation` verb. The voxtype options and the status-window bind apply only to the voxtype backend.
- `marchyo toggle gaps` and `transparency` apply through `hyprctl eval`, since `hyprctl keyword` has no effect under the Lua config.
- `rerere.autoupdate` defaults to off, so git no longer stages replayed conflict resolutions.
- Git's `merge.conflictStyle` is `diff3` instead of `zdiff3`, as the mergiraf module sets it.
- Super+1..0 (previously Super+1..5), Super+Shift+1..0 and Super+Shift+Alt+1..0 act on the focused monitor's workspaces; Super+Tab, Super+Shift+Tab, Super+Ctrl+Tab and Super+scroll stay on the focused monitor; Super+Shift+Alt+arrows move a workspace into the target monitor's block. `marchyo.workspaces.perMonitor = false` keeps the global numbering.
- Panel, launcher, overview, bar and notification binds dispatch the shell's global shortcuts instead of spawning `marchyo shell`; the lock and terminal binds keep a direct exec.
- `marchyo logout`, `reboot` and `shutdown` close every window and wait up to 2 s for the apps in a transient user unit, then end the session or run `systemctl reboot|poweroff --no-wall`.
- Shell services are event-driven: the camera indicator scans on inotify events on `/dev/video*`, caffeine and night light are shell-owned state the CLI reports to, screen recording follows a marker file `marchyo capture record` holds, the lock-key widget re-reads on Caps Lock and Num Lock binds, and the charger rating follows power_supply uevents.

- `marchyo.keyboard.autoActivateIME` defaults to `false` and sets fcitx5 `ActiveByDefault`.
- `__GLX_VENDOR_LIBRARY_NAME`, `GBM_BACKEND` and `LIBVA_DRIVER_NAME=nvidia` are set only when NVIDIA drives the display, not under PRIME offload or reverse sync; `LIBVA_DRIVER_NAME=radeonsi` only when AMD is the primary GPU.

- BBR congestion control with the fq qdisc and TCP MTU probing are on by default, outside `marchyo.performance.tuning.network`.
- A single `nix/caches.json` is now the binary cache list, and prefetch queries every configured cache and substitutes each path from whichever one has it. ([615cb0478b](https://github.com/Jylhis/j10s/commit/615cb0478b))
- Dependency updates (1 commit).
- The systemd-boot menu is hidden by default (`boot.loader.timeout = 0`). Hold Space at power-on to open it.
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
- Agents panel: compact animated usage meters, reset clocks, usage and data-age tooltips and status hints.

### Removed

- `marchyo.defaults.browser` no longer sets `$BROWSER`. xdg-settings mapped it to the first desktop file running the browser binary (often a Chrome web app), so the browser reported it was not the default.
- `lib/hex-byte.nix` and `lib/camel-case.nix`: callers use nixpkgs `lib.fromHexString` and `lib.toCamelCase`, which give the same results on token names and two-digit hexes.
- Packages `hype`, `signed` and `monologue`: no module, host or other package used them.
- The night light bind (`Super+Ctrl+N`) and the nmtui bind on `Super+Ctrl+W`.
- OBS Studio and lazydocker are no longer installed, and the `SUPER + ALT + D` lazydocker bind is removed. Add the packages with `environment.systemPackages` if you want them.
- The `/search/` demo page on marchyo.org, with its `site-option-paths` check and `site-option-defaults` eval test.
- The packages and options browser pages of the fleet app at marchyo.org/os.

### Fixed

- Plugins that replace a launcher role (`omarchy.menu`, `.emojis`, `.clipboard`) open again: `Plugins/PluginLayer` no longer names its root `layer`, which every `Item`'s own `layer` property shadowed, so `inject` failed and the plugin never registered with `PluginHost`. `Super + R`, `Super + Space`, `Super + Ctrl + E|V` and `Super + K` work again.
- Container DNS on podman networks: `modules/nixos/containers.nix` set `dns_enable`, which podman ignores; it now sets `dns_enabled`.
- The shell no longer throws a TypeError at startup: `Services/Motion` still ran the `mkdir` for the removed reduce-motion marker file.
- Clearing, deleting or evicting entries in the omarchy clipboard plugin removes their stored images: the shell deletes files in `clipboard-images` that the saved history no longer references (older than a minute, so a capture in progress stays).
- Plugin menus see installed and removed applications: the plugin app library emits `appsChanged` when `DesktopEntries.applications` changes.
- The omarchy menu that replaces the launcher applies `~/.config/marchyo/menu.local.json` like the native menu: the shell renders the merged tree into omarchy's menu extension and rewrites it when `menu.json`, the overlay or the keybinding sheet changes.
- The omarchy dropbox and tailscale bar widgets share one seat-global service, so a second monitor no longer starts a second set of status timers and processes.
- The omarchy media bar widget finds its service again: plugin bar widgets get their `PluginShellApi` as `bar.shell`, and `firstPartyServiceFor` reaches the plugin's own service (and, for a `bar` plugin, the `omarchy.*` services other than polkit).
- Clicking or scrolling the omarchy workspaces bar widget switches workspaces again: `shell/compat/rewrite.sed` turns its `o.workspaces.` dispatches into `marchyo.workspaces.`, and a contract test checks every such dispatch names a function the Hyprland Lua module defines.
- A replacement panel opens on the output it was asked for: the clicked bar's monitor, the Control Center's monitor for a detail page, or the focused monitor for a key or IPC summon, instead of the first registered bar widget. Hiding and the open state cover every monitor's widget.
- Plugin panels that replace native ones are mutually exclusive: opening one replacement, or a native panel, closes any other open replacement, and the selected one still toggles.
- `marchyo plugin add` and `marchyo plugin dev` keep the manifest `replaces` list (also in sibling entries and the user state), so a plugin that replaces a native role builds and the dev index keeps the replacement.
- Chromium, Chrome and Brave follow the runtime light/dark switch: the `BrowserThemeColor` policy, pinned to the build-time background, is gone, and so is the `chromium-policy.json` theme surface.
- Skip the default email web app when `marchyo.defaults.email` is unset, which failed evaluation with `expected a string but found null`.
- Skip the default email web app when `marchyo.defaults.email` is unset, which failed evaluation with `expected a string but found null`.
- Marchyo owns the effective runtime theme and derives the desktop preference from it. Activation restores saved selections or initializes the Nix default; packaged dconf works under the restricted activation PATH. Failed preference updates preserve the previous selection and return an error.

- The shell failed to start: the launcher declared a method named `escape`, which shadows the JavaScript global, so QML rejected `LauncherWindow`. The offscreen harness now compiles every top-level shell window.
- Dev plugins never mount at shell start: the dev loader forces `keepLoaded` off. `marchyo.shell.barPlugin` is emitted as a JSON string in `Config.qml`.
- `omarchy-bar set` serialises its read-modify-write under a lock and the host skips non-JSON values, so a plugin saving several keys no longer loses settings. `omarchy-pkg-present` no longer reports installed packages as missing (pipefail with `grep -q`) or treats the name as a regex, and `omarchy-shell` stops with one line when `MARCHYO_SHELL_ROOT` is unset.
- `marchyo plugin dev` and `plugin.nix` refuse plugin ids that do not match `[A-Za-z0-9][A-Za-z0-9._-]*` or contain `..`, so a manifest id can no longer make the dev loader delete or overwrite directories outside the dev dir, and sibling ids are quoted in the build script. `plugin dev` also validates the synced copy and keeps one SIGINT listener under `--watch`.
- The shell loads again: the launcher's power provider holds its hibernation `FileView` in a property, and the offscreen harness now instantiates every launcher provider.
- `marchyo toggle nightlight` sets the temperature over `hyprctl hyprsunset` instead of starting a second hyprsunset that kept `hyprsunset.service` from starting.
- `superwhisper-setup` orders after `graphical-session.target`, which breaks the ordering cycle that made systemd drop it at login.
- `composeKey` defaults to `"menu"` when `marchyo.keyboard.options` remaps Caps Lock (`ctrl:swapcaps`, `ctrl:nocaps`, `caps:*`); Shift+Caps compose with such an option is an assertion error, as its `<CAPS>` symbols turned both keys into Caps Lock.
- fcitx5 starts once, from its XDG autostart unit, not also from Hyprland.
- Shell Ui kit: the reduce-motion watch survives a fresh profile, the Elsewhen search submits on Enter, a closed searchable dropdown drops its filter focus, and ConfirmDialog restores focus on close and traps all arrow keys.
- The marchyo.org site builds again on Tailwind CSS 4 (Vite plugin instead of the v3 PostCSS setup); TypeScript stays on 6 for `astro check`.
- `marchyo-wallpapers` `passthru.light` and `passthru.dark` resolve to the realised output path instead of a dangling `placeholder`.
- fcitx5 is configured only when `marchyo.desktop.enable` is set, so headless hosts no longer get the graphical input method.
- Dead `mediaTools` list removed from `packages.nix`; `hyprmon` declares Linux platforms.
- The `grok` agent (`marchyo.ai.agents`) installs xAI's Grok Build CLI from llm-agents.nix instead of the unrelated `grok-cli` package.
- The pre-switch update diff hook and `marchyo diff` call `dix diff`, which dix 3.0 requires. ([c1aec544d2](https://github.com/Jylhis/j10s/commit/c1aec544d2))
- Ghostty loads a Ghostty-only GTK stylesheet that shrinks its tab bar font without changing the interface font of other GTK apps. ([69169c8b29](https://github.com/Jylhis/j10s/commit/69169c8b29))
- Hyprland sets `quirks:skip_non_kms_dmabuf_formats = false`, so a monitor that reconnects on DPMS wake no longer gets Mesa clients such as Ghostty and marchyo-shell disconnected by Hyprland 0.57.0.
- Printers run driverless: USB printers are served through ipp-usb, and cups-browsed is off by default because its queues stuck at NO_DEST_FOUND while CUPS creates IPP Everywhere queues itself. ([35a4de787a](https://github.com/Jylhis/j10s/commit/35a4de787a))

### Security

- ARP answers and announcements use only the interface's own address (`arp_ignore = 1`, `arp_announce = 2`), so a dock's Ethernet and Wi-Fi on one network keep their own routes.
- The minimal installer ISO allows key-only root SSH (`prohibit-password`, no password authentication) instead of password root login.

## 2026-10

### Added

- **Theming without rebuilds:** bat, fzf, hyprlock, console colours (via `setvtrgb`), k9s, lazygit, spotify-player and gdu now switch at runtime from per-theme directories, and `marchyo theme generate` restyles the whole desktop from a wallpaper palette. `marchyo.theme.followWallpaper` makes wallpaper changes generate a matching theme. ([f045fce06a](https://github.com/Jylhis/j10s/commit/f045fce06a), [42c3116e41](https://github.com/Jylhis/j10s/commit/42c3116e41), [a797211626](https://github.com/Jylhis/j10s/commit/a797211626))
- **Shell palette and panels:** the launcher becomes a prefix-routed command palette (`=` maths, `>theme`, `#` windows, `!` power) with clipboard image thumbnails, a Control Center (SUPER+SHIFT+Q) offers volume and mic sliders plus tiles for Wi-Fi, Bluetooth, Tailscale, DND, caffeine, night light and power profile, and SUPER+grave opens a per-monitor workspace overview with live window previews. The bar gains camera-in-use, lock-key, clock-seconds and battery readouts, a power panel and a segmented style. ([9163f13cb7](https://github.com/Jylhis/j10s/commit/9163f13cb7), [e551702ee6](https://github.com/Jylhis/j10s/commit/e551702ee6), [a74167fe44](https://github.com/Jylhis/j10s/commit/a74167fe44))
- **Shell settings, plugins and commands:** `marchyo.shell.settings` is a typed submodule with per-monitor overrides, plugins declare typed kinds (bar widget, launcher, daemon) and are pinned in a lock file, new `marchyo shell`, `volume`, `brightness` and `doctor` commands report health with `--json`, and `marchyo share` sends files to LocalSend devices on the LAN. ([4640cdff55](https://github.com/Jylhis/j10s/commit/4640cdff55), [e97d19cfc1](https://github.com/Jylhis/j10s/commit/e97d19cfc1), [6474650517](https://github.com/Jylhis/j10s/commit/6474650517))
- Dictation discards recordings with no speech, caffeine holds automatically while a video plays, toasts can be driven from the keyboard, a `reduceMotion` option turns off animations, blur and shadows (default in VM guests), and the Trigger menu gains a speed test. ([9e213e830f](https://github.com/Jylhis/j10s/commit/9e213e830f), [b8ffed15f0](https://github.com/Jylhis/j10s/commit/b8ffed15f0), [9505be802c](https://github.com/Jylhis/j10s/commit/9505be802c))

### Changed

- **Quickshell shell is the default:** `marchyo.desktop.enable` now turns on the in-house shell for bar, launcher, notifications, lock and polkit; the bar spans the screen flush with windows, with the rounded floating pill available as `floatingBar`. The greeter follows the session theme and shakes on a failed login, and the lock screen shows its card only on the focused output. ([6df45de72c](https://github.com/Jylhis/j10s/commit/6df45de72c), [fb49bd5fb2](https://github.com/Jylhis/j10s/commit/fb49bd5fb2), [6b9c357e8a](https://github.com/Jylhis/j10s/commit/6b9c357e8a))
- Stylix and its flake inputs are removed: lazygit, k9s, spotify-player, Emacs, GNOME fonts and the cursor are themed directly from base16 slots, and Qt apps follow the live GTK theme. ([8ff3a33e18](https://github.com/Jylhis/j10s/commit/8ff3a33e18), [97d74c5f2c](https://github.com/Jylhis/j10s/commit/97d74c5f2c), [e01468a9ea](https://github.com/Jylhis/j10s/commit/e01468a9ea))
- **Fonts and design:** the desktop moves to Fira Sans, IBM Plex Mono and Jost (after a brief Geist stage) with family names shared through `lib.fonts`, and the design system and docs site are restyled to the flat, bevelled 5.0 and 6.0 looks, gaining an Icon component, form controls, popovers, drawers, a navbar and an `elements.css` that styles plain HTML. ([62eb502581](https://github.com/Jylhis/j10s/commit/62eb502581), [deee8da6ca](https://github.com/Jylhis/j10s/commit/deee8da6ca), [f8a4305d0c](https://github.com/Jylhis/j10s/commit/f8a4305d0c))
- Desktops run a weekly `nh clean` (ten generations, 14 days) with store optimisation, hugePages tuning uses madvise-only transparent huge pages, and the power menu adds Log out, Lock + suspend, Restart shell and Reboot to firmware. ([a97088bc1b](https://github.com/Jylhis/j10s/commit/a97088bc1b), [c1e5299e4c](https://github.com/Jylhis/j10s/commit/c1e5299e4c), [a8d1b59373](https://github.com/Jylhis/j10s/commit/a8d1b59373))
- Dependency updates (2 commits).

### Removed

- The Vicinae, noctalia, waybar, mako and SwayOSD fallbacks and the `osd` option are retired, as are the gaming, snapper and hibernation modules and the kmscon console and local Ollama modules added earlier in the month, which give way to upstream NixOS options; the cmus, neomutt and ncspot modules and the litellm gateway backend go too. ([58877d591a](https://github.com/Jylhis/j10s/commit/58877d591a), [a24a367973](https://github.com/Jylhis/j10s/commit/a24a367973), [dd04ad57e1](https://github.com/Jylhis/j10s/commit/dd04ad57e1))
- nix-darwin support is removed, including `mkDarwinSystem`, the darwin modules and the wallpapper package. ([bc85806f5c](https://github.com/Jylhis/j10s/commit/bc85806f5c))

### Fixed

- The audio panel no longer flickers, bar widgets no longer vanish, windows no longer tile under the bar and Qt 6.12 no longer turns shell colours black; runtime theme switches no longer break the next Home Manager activation, and Bluetooth enables the ISO socket experiment for LE Audio. ([ec58734c9a](https://github.com/Jylhis/j10s/commit/ec58734c9a), [385cefb220](https://github.com/Jylhis/j10s/commit/385cefb220), [447aec5718](https://github.com/Jylhis/j10s/commit/447aec5718))

### Security

- The ncro cache proxy listens on 127.0.0.1 only, and the CLI moves to zod 4 and the site to current Astro, Starlight and wrangler, clearing the remaining scanner findings. ([a66b77e00f](https://github.com/Jylhis/j10s/commit/a66b77e00f), [18f7479c0a](https://github.com/Jylhis/j10s/commit/18f7479c0a), [4777409a0b](https://github.com/Jylhis/j10s/commit/4777409a0b))

## 2026-09

### Added

- **Quickshell shell grows up:** a native session lock with in-process PAM, a greeter that replaces tuigreet under cage, an in-shell launcher with fuzzy app search, emoji picker and clipboard history, and a notification centre (SUPER+N) with persistent history and `marchyo.notifications.rules`. With the shell on, idle, sleep and SUPER+L use its lock and SUPER+R opens its launcher. ([10a2f9f324](https://github.com/Jylhis/j10s/commit/10a2f9f324), [f4b7f76624](https://github.com/Jylhis/j10s/commit/f4b7f76624), [32a4345449](https://github.com/Jylhis/j10s/commit/32a4345449))
- Bar widgets for media, wireless peripheral battery, microphone use, weather, Tailscale, reminders, screen recording, night light and the active window, with panels for weather, Tailscale, Wi-Fi sharing by QR code and per-application audio streams with live peak meters. ([1f696cd453](https://github.com/Jylhis/j10s/commit/1f696cd453), [c8eb94bf26](https://github.com/Jylhis/j10s/commit/c8eb94bf26), [88d05716d8](https://github.com/Jylhis/j10s/commit/88d05716d8))
- **Live themes:** `marchyo theme set` and `next` restyle GTK and the dconf scheme live from runtime theme directories, `marchyo theme generate` builds a palette from a wallpaper through matugen, and `marchyo.theme.appearance` scales corner radius, animation speed and border contrast. ([64232bad54](https://github.com/Jylhis/j10s/commit/64232bad54), [e9650a6d0e](https://github.com/Jylhis/j10s/commit/e9650a6d0e), [6b3298d2cf](https://github.com/Jylhis/j10s/commit/6b3298d2cf))
- **Shell plugins:** a `qs.compat` shim runs upstream omarchy Quickshell plugins nearly unmodified, managed with `marchyo plugin add`, `list` and `remove`. ([e179f1337d](https://github.com/Jylhis/j10s/commit/e179f1337d), [5686a2814b](https://github.com/Jylhis/j10s/commit/5686a2814b), [deacfddd5e](https://github.com/Jylhis/j10s/commit/deacfddd5e))
- `marchyo.monitors` declares monitor layout as typed data, `marchyo.defaults.excludePackages` trims default bundles, opt-in gaming (Steam, Gamescope), ddcutil and fwupd modules arrive, dictation gains jargon replacements and spoken punctuation, and Hyprland hides the cursor while typing. ([7679054e10](https://github.com/Jylhis/j10s/commit/7679054e10), [fcd186d4b9](https://github.com/Jylhis/j10s/commit/fcd186d4b9), [2bdf12fd40](https://github.com/Jylhis/j10s/commit/2bdf12fd40))
- An on-demand security suite adds a lynis hardening VM test, an SBOM app and a vulnerability scan, and the ncro cache router fronts a single `marchyo.nix.caches` list. ([286292167b](https://github.com/Jylhis/j10s/commit/286292167b), [ea1f61f546](https://github.com/Jylhis/j10s/commit/ea1f61f546))

### Changed

- marchyo adopts the single-theme jylhis-design 3.0.0 (`jylhis-dark` and `jylhis-light`), and scheme YAML comes from a fetched flake input so evaluation no longer forces a build. ([bcd05a2071](https://github.com/Jylhis/j10s/commit/bcd05a2071), [f1a0a562b6](https://github.com/Jylhis/j10s/commit/f1a0a562b6), [25ffe294e7](https://github.com/Jylhis/j10s/commit/25ffe294e7))
- Development tools default to rootless Podman with Docker CLI compatibility, and desktop-only modules gate on `marchyo.desktop.enable` with `mkDefault` service defaults. ([ece272dfee](https://github.com/Jylhis/j10s/commit/ece272dfee), [5b43d624a0](https://github.com/Jylhis/j10s/commit/5b43d624a0))
- The jotain Emacs integration is dropped, so the default editor is plain Emacs with `emacsclient` as `EDITOR` and `VISUAL`. ([9a0502e580](https://github.com/Jylhis/j10s/commit/9a0502e580))
- Dependency updates (1 commit).

### Removed

- The `marchyo.ai` namespace (OpenRouter settings, per-user AI tooling, MCP wiring), the `llm-agents` input, the `openviking` and `pi` packages, and the vendored worktrunk module in favour of Home Manager's `programs.worktrunk`. ([6f8c3e5c6b](https://github.com/Jylhis/j10s/commit/6f8c3e5c6b), [dd6376a100](https://github.com/Jylhis/j10s/commit/dd6376a100), [5f6f0edf9c](https://github.com/Jylhis/j10s/commit/5f6f0edf9c))

### Fixed

- Shell fixes: greeter and launcher crash loops, a black login screen, caffeine indicator flicker, per-monitor duplicate probes and the network widget's IP address; runtime theme colours reach Hyprland through `hl.config`, since `hyprctl keyword` did nothing under the Lua parser. ([73bb5426bc](https://github.com/Jylhis/j10s/commit/73bb5426bc), [4c10b9cc49](https://github.com/Jylhis/j10s/commit/4c10b9cc49), [970186c942](https://github.com/Jylhis/j10s/commit/970186c942))
- Snapshot limits no longer prune daily snapshots, disko layouts require an explicit target device, light-variant rebuilds no longer hit dconf conflicts, and gaming no longer breaks aarch64 evaluation. ([4bee27a97d](https://github.com/Jylhis/j10s/commit/4bee27a97d), [1982d89b75](https://github.com/Jylhis/j10s/commit/1982d89b75), [9f32c63042](https://github.com/Jylhis/j10s/commit/9f32c63042))

## 2026-08

### Added

- **Quickshell shell:** an opt-in `marchyo.shell` top bar themed from the Jylhis tokens reaches waybar parity (workspaces, tray, audio, battery, network, Bluetooth, CPU, caffeine, DND and dictation widgets with tooltips and tray menus). Enabling it retires waybar, SwayOSD and mako: the shell draws its own volume and brightness overlay, owns notifications and opens panels for audio, network, battery and system monitoring. ([ead48f9b6f](https://github.com/Jylhis/j10s/commit/ead48f9b6f), [109f9e6416](https://github.com/Jylhis/j10s/commit/109f9e6416), [2dc69411df](https://github.com/Jylhis/j10s/commit/2dc69411df))
- A `marchyo.launcher` module runs the Vicinae launcher on SUPER+R with generated themes, and a caffeine keep-awake toggle sits on SUPER+CTRL+K with a bar indicator. ([81906602f5](https://github.com/Jylhis/j10s/commit/81906602f5), [edfd1356b0](https://github.com/Jylhis/j10s/commit/edfd1356b0))
- An end-user manual with fifteen chapters is published under `/manual` on the documentation site. ([2803b79afb](https://github.com/Jylhis/j10s/commit/2803b79afb))
- `marchyo.identity` unifies user and group declarations across NixOS and darwin, with per-person identity files. ([8633b848a3](https://github.com/Jylhis/j10s/commit/8633b848a3))

### Changed

- Hyprland settings move from hyprlang to the Lua renderer, reshaping binds, window rules and startup hooks. ([9923dea9b8](https://github.com/Jylhis/j10s/commit/9923dea9b8))

### Removed

- The self-tracking telemetry stack (auditd, Vector, ActivityWatch, atuin, WakaTime) and its `marchyo.tracking` options, plus aichat, the Kitty and Xournal++ modules and the zeal docs browser. ([4a07583bc6](https://github.com/Jylhis/j10s/commit/4a07583bc6), [86cd0cb979](https://github.com/Jylhis/j10s/commit/86cd0cb979), [75a0fc2a75](https://github.com/Jylhis/j10s/commit/75a0fc2a75))
- Bash is the only configured login shell, with the zsh and fish integrations removed, and the deprecated `marchyo.inputMethod` options are gone, so setting them is an error. ([8188ee9991](https://github.com/Jylhis/j10s/commit/8188ee9991), [f76e9a5884](https://github.com/Jylhis/j10s/commit/f76e9a5884))

### Fixed

- Hyprland no longer exports an unexpanded `XDG_DATA_DIRS` literal that hid most applications from the launcher, and the `marchyo-shell` service no longer crash-loops on startup. ([84438074fa](https://github.com/Jylhis/j10s/commit/84438074fa), [e29a1e0366](https://github.com/Jylhis/j10s/commit/e29a1e0366))
- aerc headers are readable in the light theme, desktop journal warnings are silenced, wf-recorder builds against ffmpeg 8, and the docs search page clears stale results. ([7989b7665b](https://github.com/Jylhis/j10s/commit/7989b7665b), [64fb8da3e9](https://github.com/Jylhis/j10s/commit/64fb8da3e9), [9e4109f476](https://github.com/Jylhis/j10s/commit/9e4109f476))

### Security

- Users are no longer added to the root-equivalent docker group by default; `containers.backend` and `dockerGroup` make it an explicit opt-in. ([2e8f2528e5](https://github.com/Jylhis/j10s/commit/2e8f2528e5))

## 2026-07

### Added

- **marchyo CLI:** a Bun-built `marchyo` CLI (status, theme, rebuild, update, rollback, gc, diff, debug) and the `marchyoctl` developer CLI are introduced, then reach 1.0 with a frozen command surface, snapshot tests, completions and a man page. ([2736ce4a42](https://github.com/Jylhis/j10s/commit/2736ce4a42), [4a29323954](https://github.com/Jylhis/j10s/commit/4a29323954), [d041d27082](https://github.com/Jylhis/j10s/commit/d041d27082))
- A runtime-first change engine lets `marchyo theme`, `toggle`, `capture`, `menu`, `launch`, `monitor`, `reminder`, `font`, `install`, `remove` and `security enroll` act on the running desktop and restore overrides at startup, replacing the earlier shell scripts. ([c5857d37fe](https://github.com/Jylhis/j10s/commit/c5857d37fe), [437afcf1ef](https://github.com/Jylhis/j10s/commit/437afcf1ef), [d6cc5c6776](https://github.com/Jylhis/j10s/commit/d6cc5c6776))
- **Omarchy-style desktop:** a central menu (SUPER+ALT+Space), a power menu, a terminal screensaver, do-not-disturb with a bar indicator, web apps with launch keys, OCR and colour-picker screenshots, universal copy and paste binds, and a dark/light theme toggle. ([e1bfef122d](https://github.com/Jylhis/j10s/commit/e1bfef122d), [5fda613031](https://github.com/Jylhis/j10s/commit/5fda613031), [68a549e2a4](https://github.com/Jylhis/j10s/commit/68a549e2a4))
- Opt-in push-to-talk dictation with voxtype and Whisper (hold-to-talk on F9), Waybar recording indicator and GPU or CPU builds. ([948b18eb67](https://github.com/Jylhis/j10s/commit/948b18eb67), [5b94bff54a](https://github.com/Jylhis/j10s/commit/5b94bff54a), [23284b851b](https://github.com/Jylhis/j10s/commit/23284b851b))
- Service and hardware options: `marchyo.services.localsend` and `tailscale`, `marchyo.power.hibernation`, `marchyo.performance.kernel`, `marchyo.security.fingerprint` and `fido2`, `marchyo.bees` deduplication and a `nixosModules.hardware` re-export. ([bb2a1154c1](https://github.com/Jylhis/j10s/commit/bb2a1154c1), [14a1888791](https://github.com/Jylhis/j10s/commit/14a1888791), [9ccfe461d3](https://github.com/Jylhis/j10s/commit/9ccfe461d3))
- A static Astro and Starlight documentation site replaces the Mintlify pages, with a man-page landing page, a paper and roast theme toggle, and package and option search backed by a Cloudflare D1 index. ([8845d5ce4c](https://github.com/Jylhis/j10s/commit/8845d5ce4c), [c39ede5fb1](https://github.com/Jylhis/j10s/commit/c39ede5fb1), [cd7e709ae5](https://github.com/Jylhis/j10s/commit/cd7e709ae5))
- `marchyo.theme.themes` defines runtime-switchable themes and `marchyo.theme.fontScale` (default 1.25x) scales every text surface. ([c7b8a8ac6b](https://github.com/Jylhis/j10s/commit/c7b8a8ac6b), [bb48e50179](https://github.com/Jylhis/j10s/commit/bb48e50179))

### Changed

- **Jylhis Design System v2:** cool grounds, bronze accent, Zilla Slab, Hanken Grotesk and Plex Mono across generated targets, with variants renamed Field and Sheet and an animated Plymouth splash. ([489b6ce50a](https://github.com/Jylhis/j10s/commit/489b6ce50a), [a9b00cffe4](https://github.com/Jylhis/j10s/commit/a9b00cffe4), [a2a43e072f](https://github.com/Jylhis/j10s/commit/a2a43e072f))
- Bash becomes the default login shell on every platform, screenshot binds move to Super+S, the scratchpad to Super+D, and Waybar clicks open floating popups. ([9133baa9e8](https://github.com/Jylhis/j10s/commit/9133baa9e8), [60741b92ea](https://github.com/Jylhis/j10s/commit/60741b92ea), [9e682d8645](https://github.com/Jylhis/j10s/commit/9e682d8645))
- Dependency updates (3 commits).

### Removed

- The GitHub Pages docs workflow and the `docs`, `docs-options` and `docs-lib` package outputs, a breaking change for consumers. ([c7fd4c7586](https://github.com/Jylhis/j10s/commit/c7fd4c7586))

### Fixed

- The crash-prone iwd Wi-Fi backend gives way to NetworkManager's default, the starship prompt renders on bash again, and the jotain daemon opens GUI frames from a cold start. ([9451f3dcda](https://github.com/Jylhis/j10s/commit/9451f3dcda), [028bf8b82e](https://github.com/Jylhis/j10s/commit/028bf8b82e), [3450068668](https://github.com/Jylhis/j10s/commit/3450068668))

## 2026-06

### Added

- Opt-in `marchyo.performance.tuning` (BBR, NVMe scheduling, dirty pages, huge pages) and a two-disk btrfs RAID1 disko template over per-device LUKS2. ([f8aa41df7f](https://github.com/Jylhis/j10s/commit/f8aa41df7f), [a843212f86](https://github.com/Jylhis/j10s/commit/a843212f86))
- A bring-your-own-key `marchyo.ai` desktop with pi and Claude Code clients, OpenRouter routing and Agent Skills. ([07d90e71e3](https://github.com/Jylhis/j10s/commit/07d90e71e3))
- A nix-on-droid terminal configuration and `lib.mkNixosSystem`, `mkDarwinSystem` and `mkNixOnDroidConfiguration` builders. ([a85c88a726](https://github.com/Jylhis/j10s/commit/a85c88a726), [4c7a555b9e](https://github.com/Jylhis/j10s/commit/4c7a555b9e), [0773caaae4](https://github.com/Jylhis/j10s/commit/0773caaae4))
- Token-derived wallpapers, a searchable keybinding cheat sheet (SUPER+K), hardened SSH defaults and trash-cli. ([fa263d3aac](https://github.com/Jylhis/j10s/commit/fa263d3aac), [4c57e6d39f](https://github.com/Jylhis/j10s/commit/4c57e6d39f), [5d4b29ffc7](https://github.com/Jylhis/j10s/commit/5d4b29ffc7))

### Changed

- Terminal tools replace GUI defaults (btop, qalc, yazi, spotify-player, aerc), and the Hyprland desktop takes a tmux-style look with square corners and flat panes. ([f8e100b6d2](https://github.com/Jylhis/j10s/commit/f8e100b6d2), [c3356eb207](https://github.com/Jylhis/j10s/commit/c3356eb207), [173990db74](https://github.com/Jylhis/j10s/commit/173990db74))
- Jotain Emacs becomes the real default editor, and Wayland modules apply only on Linux with desktop enabled. ([1a937331f9](https://github.com/Jylhis/j10s/commit/1a937331f9), [a0a5455ed0](https://github.com/Jylhis/j10s/commit/a0a5455ed0))
- Dependency updates (2 commits).

### Fixed

- Mako runs as the notification daemon again, and enabled users join the onepassword group. ([7a56367d5e](https://github.com/Jylhis/j10s/commit/7a56367d5e), [689e0a0d2c](https://github.com/Jylhis/j10s/commit/689e0a0d2c))
- The OpenViking key is injected safely, and x86_64-darwin evaluates against matching stable inputs. ([724173d155](https://github.com/Jylhis/j10s/commit/724173d155), [6aaab15749](https://github.com/Jylhis/j10s/commit/6aaab15749))

### Security

- Screenshot and tracking privacy filters are hardened, password managers are skipped regardless of case, and disabled users lose trusted and docker access. ([59645a80ec](https://github.com/Jylhis/j10s/commit/59645a80ec), [bf6ed3ff8f](https://github.com/Jylhis/j10s/commit/bf6ed3ff8f))

## 2026-05

### Added

- A `marchyo.emacs` namespace runs a PGTK daemon with Hyprland focus movement, a scratchpad frame and org-capture binds. ([5216732fed](https://github.com/Jylhis/j10s/commit/5216732fed))
- Laurel audit logging to Vector and Loki, per-editor WakaTime options, and darwin defaults with Homebrew casks plus opt-in Solaar and Slack modules. ([e692e6afce](https://github.com/Jylhis/j10s/commit/e692e6afce), [8803821443](https://github.com/Jylhis/j10s/commit/8803821443), [2c951afe5b](https://github.com/Jylhis/j10s/commit/2c951afe5b))
- fzf file and directory widgets with previews, zoxide in place of cd, and delta as the git pager. ([f9bf018359](https://github.com/Jylhis/j10s/commit/f9bf018359))

### Changed

- Theming moves to the Jylhis Design System, with a shared palette helper driving the console, Ghostty, mako, GTK and fzf, Literata and JetBrains Mono fonts, and the design consumed as a proper flake. ([0e1d88e5db](https://github.com/Jylhis/j10s/commit/0e1d88e5db), [104deb63ba](https://github.com/Jylhis/j10s/commit/104deb63ba), [2bdbee67fd](https://github.com/Jylhis/j10s/commit/2bdbee67fd))
- The default keyboard layout becomes us(altgr-intl) with Compose on the Menu key, and modules, options and tests are auto-discovered from their directories. ([d766d72ef7](https://github.com/Jylhis/j10s/commit/d766d72ef7), [349501772d](https://github.com/Jylhis/j10s/commit/349501772d))
- Nixpkgs, home-manager and nix-darwin are pinned to the 26.05 release branches. ([66a37b746b](https://github.com/Jylhis/j10s/commit/66a37b746b))

### Removed

- The Starship prompt module, and the wofi launcher module in favour of Vicinae. ([a0748ee1ed](https://github.com/Jylhis/j10s/commit/a0748ee1ed), [104deb63ba](https://github.com/Jylhis/j10s/commit/104deb63ba))

### Fixed

- Hyprland config tracks removed options, and darwin evaluation works with Linux-only theme modules. ([c18501b22d](https://github.com/Jylhis/j10s/commit/c18501b22d), [b1ad2c2416](https://github.com/Jylhis/j10s/commit/b1ad2c2416))

## 2026-04

### Added

- Opt-in `marchyo.tracking`: local-first activity collectors for shell, desktop, editor, git and system, aggregated into a weekly analysis report with optional local LLM insights, plus atuin, ActivityWatch and WakaTime wiring. ([a0363e0e1f](https://github.com/Jylhis/j10s/commit/a0363e0e1f), [b7bfac0d5b](https://github.com/Jylhis/j10s/commit/b7bfac0d5b), [caf066e64a](https://github.com/Jylhis/j10s/commit/caf066e64a))
- A generated documentation site of module option and library function references, and Darwin, standalone Home Manager and aarch64 NixOS configurations. ([9304a21e5c](https://github.com/Jylhis/j10s/commit/9304a21e5c), [508517c297](https://github.com/Jylhis/j10s/commit/508517c297))
- A shared zsh configuration with completion and history search. ([debd408486](https://github.com/Jylhis/j10s/commit/debd408486))

### Changed

- Ghostty replaces kitty as the default terminal. ([08fe5ded43](https://github.com/Jylhis/j10s/commit/08fe5ded43))
- Nix logic moves into `default.nix`, `overlay.nix` and `treefmt.nix` with a `Justfile` for common tasks. ([0a90d523a8](https://github.com/Jylhis/j10s/commit/0a90d523a8))
- Dependency updates (1 commit).

### Removed

- The worktrunk module, whose import-from-derivation broke cross-architecture evaluation. ([e916b10844](https://github.com/Jylhis/j10s/commit/e916b10844))

### Fixed

- Ghostty alt+1 to alt+9 tab bindings work on Linux GTK, and tracking analysis uses UTC and no longer double-counts active time. ([1b23d7daa4](https://github.com/Jylhis/j10s/commit/1b23d7daa4), [d60e7074d8](https://github.com/Jylhis/j10s/commit/d60e7074d8))
- Chrome and Spotify defaults fall back sensibly on non-x86_64 Linux. ([44b3f320d7](https://github.com/Jylhis/j10s/commit/44b3f320d7))

## 2026-03

### Added

- `marchyo.defaults` picks browser, editors, players, file manager and email, with jotain available as an editor choice. ([c4a6b922d4](https://github.com/Jylhis/j10s/commit/c4a6b922d4), [ac9c540055](https://github.com/Jylhis/j10s/commit/ac9c540055))
- `marchyo.keyboard.composeKey` and a keyboard guide, JACK audio, XDG user directories and a Mintlify documentation site. ([e1b8eb330f](https://github.com/Jylhis/j10s/commit/e1b8eb330f), [036290b4ba](https://github.com/Jylhis/j10s/commit/036290b4ba), [e6d96d00e1](https://github.com/Jylhis/j10s/commit/e6d96d00e1))
- A `marchyo-config` Claude Code skill is installed for managed users in development mode. ([c6ba793708](https://github.com/Jylhis/j10s/commit/c6ba793708))

### Changed

- Hyprland starts via UWSM with early-loaded NVIDIA modules, the desktop profile enables dconf and Nautilus support, and worktrunk is enabled only in development mode. ([22fa88b24b](https://github.com/Jylhis/j10s/commit/22fa88b24b), [1c2308318c](https://github.com/Jylhis/j10s/commit/1c2308318c), [55a48436e8](https://github.com/Jylhis/j10s/commit/55a48436e8))

### Security

- CPU mitigations stay on unless `marchyo.performance.disableMitigations` is set, and `accept-flake-config` is no longer enabled. ([7b98a1e5f4](https://github.com/Jylhis/j10s/commit/7b98a1e5f4), [4aa65a0055](https://github.com/Jylhis/j10s/commit/4aa65a0055), [ee26a7e7ae](https://github.com/Jylhis/j10s/commit/ee26a7e7ae))

### Fixed

- The `testNixOS` helper throws when any assertion fails, and deprecation warnings are silenced. ([72c45da851](https://github.com/Jylhis/j10s/commit/72c45da851), [3374cb921d](https://github.com/Jylhis/j10s/commit/3374cb921d))

## 2026-02

### Added

- A noctalia-shell input and the worktrunk tool as a Home Manager module with a TOML `settings` option. ([4be692f419](https://github.com/Jylhis/j10s/commit/4be692f419), [57f2a44271](https://github.com/Jylhis/j10s/commit/57f2a44271), [317c8a0d0a](https://github.com/Jylhis/j10s/commit/317c8a0d0a))
- A development VM app that boots a QEMU marchyo VM. ([e3ab108348](https://github.com/Jylhis/j10s/commit/e3ab108348))

### Changed

- Git defaults gain histogram diffs, prune on fetch, autosquash and autostash, and binary caching moves to the jylhis cachix cache. ([6037fd7d77](https://github.com/Jylhis/j10s/commit/6037fd7d77), [5c141381e2](https://github.com/Jylhis/j10s/commit/5c141381e2))
- Hyprland window rules use the new match syntax. ([9e0bfe7458](https://github.com/Jylhis/j10s/commit/9e0bfe7458), [d3cb886fca](https://github.com/Jylhis/j10s/commit/d3cb886fca))

### Removed

- The Dropbox module, and the FlakeHub and Determinate inputs. ([78e9386efe](https://github.com/Jylhis/j10s/commit/78e9386efe), [4f4aba50cc](https://github.com/Jylhis/j10s/commit/4f4aba50cc))

### Fixed

- A picosvg patch lets its tests pass with skia-pathops 0.9 and later. ([386d94f494](https://github.com/Jylhis/j10s/commit/386d94f494))

## 2026-01

### Added

- GPU vendor options for Intel, AMD and NVIDIA with PRIME offload, sync and reverse-sync modes, and NVIDIA Wayland environment for Hyprland. ([26da8d02ec](https://github.com/Jylhis/j10s/commit/26da8d02ec), [70a2817a0b](https://github.com/Jylhis/j10s/commit/70a2817a0b))
- Default applications and gvfs through an XDG module, plus theme and keyboard assertions and `LLM.md`, an assistant-oriented usage guide. ([8ade217716](https://github.com/Jylhis/j10s/commit/8ade217716), [7fdda947d6](https://github.com/Jylhis/j10s/commit/7fdda947d6), [5391866165](https://github.com/Jylhis/j10s/commit/5391866165))

### Changed

- Lib and module tests evaluate purely instead of building toplevels. ([f1b2e1cf21](https://github.com/Jylhis/j10s/commit/f1b2e1cf21))

### Fixed

- Mako urgency settings no longer produce an unparsable config. ([8e637a02b5](https://github.com/Jylhis/j10s/commit/8e637a02b5))

## 2025-12

### Added

- aarch64-linux is included in flake systems, with platform-gated settings. ([d90da03048](https://github.com/Jylhis/j10s/commit/d90da03048))

## 2025-11

### Added

- fcitx5 input method support with Waybar status, later unified under `marchyo.keyboard.layouts` with Chinese, Japanese and Korean IME support. ([1f76daf1ad](https://github.com/Jylhis/j10s/commit/1f76daf1ad), [eda14c6058](https://github.com/Jylhis/j10s/commit/eda14c6058), [838f9539e4](https://github.com/Jylhis/j10s/commit/838f9539e4))
- A screenshot module for Hyprland, GNOME colour-scheme and GTK theme matching, and keyboard layout options. ([5b4985e0bc](https://github.com/Jylhis/j10s/commit/5b4985e0bc), [5a1c7c0e95](https://github.com/Jylhis/j10s/commit/5a1c7c0e95), [c6cf2c8281](https://github.com/Jylhis/j10s/commit/c6cf2c8281))

### Changed

- fcitx5 is off by default and shares input state across windows. ([7ea2a2cfaf](https://github.com/Jylhis/j10s/commit/7ea2a2cfaf), [38fe6e8f6b](https://github.com/Jylhis/j10s/commit/38fe6e8f6b))

### Fixed

- A Hyprland picture-in-picture rule error, the renamed libva-vdpau-driver package, Home Manager git options and the greeter command lookup. ([51c43a2e1c](https://github.com/Jylhis/j10s/commit/51c43a2e1c), [fd16916fd6](https://github.com/Jylhis/j10s/commit/fd16916fd6), [8f6f64712f](https://github.com/Jylhis/j10s/commit/8f6f64712f))

## 2025-10

### Added

- **Option layer:** `marchyo.profile` presets (base, desktop, developer, gaming, server) with hostname and stateVersion options, `marchyo.btrfs` subvolume, compression and scrub settings, and `marchyo.firewall` port rules. ([73b4b3dbee](https://github.com/Jylhis/j10s/commit/73b4b3dbee), [1a7505fc13](https://github.com/Jylhis/j10s/commit/1a7505fc13), [41a9fa60d9](https://github.com/Jylhis/j10s/commit/41a9fa60d9))
- Opt-in sops-nix secrets, Prometheus and Grafana monitoring, kernel and systemd hardening and BTRFS root rollback. ([86dea13c5c](https://github.com/Jylhis/j10s/commit/86dea13c5c))
- Installation tooling: minimal and graphical installer ISOs, disko layouts (UEFI, LUKS with btrfs), install scripts and workstation and minimal flake templates. ([95790f2338](https://github.com/Jylhis/j10s/commit/95790f2338), [861103a0af](https://github.com/Jylhis/j10s/commit/861103a0af), [cacf32c727](https://github.com/Jylhis/j10s/commit/cacf32c727))
- Documentation and helper scripts: README, configuration guide, modules reference, troubleshooting guide, examples, `update.sh`, `rollback.sh` and `health-check.sh`. ([2877d96ea0](https://github.com/Jylhis/j10s/commit/2877d96ea0), [b75668c7f7](https://github.com/Jylhis/j10s/commit/b75668c7f7), [6ded6337eb](https://github.com/Jylhis/j10s/commit/6ded6337eb))
- `marchyo.lib.mkNixosSystem`, a colourscheme system built on nix-colors Base16 and the Modus schemes, and Vicinae and btop modules. ([fab2d47039](https://github.com/Jylhis/j10s/commit/fab2d47039), [18ac8725a5](https://github.com/Jylhis/j10s/commit/18ac8725a5), [060bde5a37](https://github.com/Jylhis/j10s/commit/060bde5a37))
- Cachix, SSH, virtualization, tmux, git-advanced, Neovim and VS Code modules, a first-boot welcome, a hyprmon monitor TUI, and a Waybar language indicator for the Hyprland keyboard layout. ([1371aaa727](https://github.com/Jylhis/j10s/commit/1371aaa727), [5740bb7461](https://github.com/Jylhis/j10s/commit/5740bb7461), [de415cabac](https://github.com/Jylhis/j10s/commit/de415cabac))

### Changed

- Legacy base, desktop and developer profiles are removed, and desktop and development settings follow their enable options. ([0a6a7eed0b](https://github.com/Jylhis/j10s/commit/0a6a7eed0b))
- Locale and timezone come from marchyo options, firmware is enabled by default, and the workstation template builds through `mkNixosSystem`. ([90a31b8494](https://github.com/Jylhis/j10s/commit/90a31b8494), [520b2eb01c](https://github.com/Jylhis/j10s/commit/520b2eb01c), [95741c812f](https://github.com/Jylhis/j10s/commit/95741c812f))
- Neovim moves from nixvim to plain `programs.neovim`, and Home Manager backs up overwritten files with a `.backup` extension. ([dfbe213037](https://github.com/Jylhis/j10s/commit/dfbe213037), [d04a3a3fce](https://github.com/Jylhis/j10s/commit/d04a3a3fce))
- Dependency updates (1 commit).

### Removed

- The 1Password shell plugins input, iwd Wi-Fi backend and impala TUI, and the flake-parts module layer. ([fb8dcac767](https://github.com/Jylhis/j10s/commit/fb8dcac767), [caab57a841](https://github.com/Jylhis/j10s/commit/caab57a841), [eab34c743f](https://github.com/Jylhis/j10s/commit/eab34c743f))

### Fixed

- Waybar no longer spawns duplicate instances after sleep, home modules apply their colour theme unconditionally, and the Vicinae theme file generates correctly. ([2682071b18](https://github.com/Jylhis/j10s/commit/2682071b18), [922887ef2b](https://github.com/Jylhis/j10s/commit/922887ef2b), [0d0598a8ad](https://github.com/Jylhis/j10s/commit/0d0598a8ad))

## 2025-09

### Added

- The first NixOS and Home Manager module set for a Hyprland desktop: Waybar, kitty, Ghostty, hyprlock, mako, wofi, fonts, audio and graphics. ([01f058c694](https://github.com/Jylhis/j10s/commit/01f058c694), [59121ef8d1](https://github.com/Jylhis/j10s/commit/59121ef8d1))
- A Marchyo Plymouth boot splash, CUPS printing, a hyprpaper wallpaper module and Home Manager git and shell modules. ([309d510ee9](https://github.com/Jylhis/j10s/commit/309d510ee9), [cb2469240d](https://github.com/Jylhis/j10s/commit/cb2469240d), [a88b47d8ea](https://github.com/Jylhis/j10s/commit/a88b47d8ea))
- `marchyo.*` options for users plus desktop, development, media and office feature flags. ([e100d48950](https://github.com/Jylhis/j10s/commit/e100d48950))
- A CI workflow running `nix flake check` with Cachix pushes and FlakeHub rolling releases. ([24fdcc604a](https://github.com/Jylhis/j10s/commit/24fdcc604a))

### Changed

- Inputs resolve through FlakeHub tarballs and Hyprland stops forcing Wayland backends for GDK, Qt and Electron apps. ([1080557886](https://github.com/Jylhis/j10s/commit/1080557886), [63934c1d20](https://github.com/Jylhis/j10s/commit/63934c1d20))
- NetworkManager is configured to use the iwd Wi-Fi backend. ([e43e3773cb](https://github.com/Jylhis/j10s/commit/e43e3773cb), [4c5d72a7ac](https://github.com/Jylhis/j10s/commit/4c5d72a7ac))
