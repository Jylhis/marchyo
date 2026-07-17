# Omarchy → Marchyo: gap analysis + implementation plan

This document has two parts:
- **Part A — Gap analysis:** a full comparison of [basecamp/omarchy](https://github.com/basecamp/omarchy) against marchyo (what's missing, what differs, what's out of scope).
- **Part B — Implementation plan:** the subset selected for porting, with concrete file-level steps.

---

# PART A — Gap analysis

## Context

Marchyo is a NixOS re-implementation of the ideas in omarchy (DHH/Basecamp's opinionated Arch + Hyprland distro). This part is a **comparison inventory**: what omarchy ships that marchyo does not, and where the two implement the same idea differently.

Both inventories were taken from **current sources**: omarchy `master` (mid-2026) read directly from the repo, and marchyo from the working checkout (includes the in-progress dictation work).

A structural fact that reframes half of omarchy's surface: **omarchy is an imperative Arch overlay** — a huge `bin/omarchy-*` script library that mutates a running system (install/remove/update/refresh/migrate). **Marchyo is declarative NixOS** — that entire category is replaced by `nixos-rebuild` + flake inputs and is *not* a gap (see §A5).

## A1. Deliberate divergences (NOT gaps)

- **Flat TUI aesthetic.** Marchyo forces `rounding=0`, `gaps=0`, `border=2`, `animations=off`, no blur/shadow. Omarchy ships those and exposes runtime toggles (`SUPER+Backspace` transparency, `SUPER SHIFT+Backspace` gaps, `SUPER CTRL+Backspace` single-window aspect). Marchyo intentionally omits those toggles.
- **App-launch keybind namespace.** Omarchy launches apps on `SUPER+SHIFT+<letter>`; marchyo on plain `SUPER+<letter>`. The whole map is shifted — not "missing".
- **`SUPER+S` / `SUPER+D`.** Marchyo (recent commit): `SUPER+S` = screenshot area, `SUPER+D` = scratchpad "Drawer". Omarchy: `SUPER+S` = scratchpad, `SUPER SHIFT+D` = lazydocker, `PRINT` = screenshot.
- **Launcher.** Omarchy = Walker + Elephant (`SUPER+SPACE`). Marchyo = Vicinae (`SUPER+R`).
- **Single theme, declarative switch.** Marchyo = one Jylhis theme, `dark`/`light` via `marchyo.theme.variant`. Omarchy = 19 themes + runtime picker.
- **noctalia present but disabled** on purpose (would seize the notification bus).

## A2. Features MISSING from marchyo (impact-ordered)

1. **Central system menu** — omarchy's `omarchy-menu` (`SUPER ALT+SPACE`): Apps · Learn · Trigger · Style · Setup · Install · Remove · Update · About · System. Marchyo has no aggregator. Even excluding the declarative-N/A branches, Trigger/Style/Setup/System/Learn have real value and no counterpart.
2. **Power/session menu** — omarchy `omarchy-system-{lock,logout,reboot,shutdown,suspend}`. Marchyo has only `SUPER+L` (hyprlock) and `CTRL ALT+Delete` (hard poweroff). No logout/reboot/suspend/hibernate affordance.
3. **On-screen display (SwayOSD)** — omarchy routes volume/brightness/mic/kbd-backlight through SwayOSD. Marchyo changes them silently.
4. **Screensaver** — omarchy `tte` (terminaltexteffects) screensaver, idle-launched, brandable. Marchyo: none.
5. **Runtime theme + background switcher** — omarchy: 19 themes, `omarchy-theme-*`, background/theme pickers, per-key keyboard RGB. Marchyo: single theme, NixOS-option variant, single generated wallpaper, no runtime switcher/cycler, no keyboard RGB.
6. **Productivity "Trigger" utilities** — reminders (`SUPER CTRL+R`…), weather (waybar + `SUPER CTRL ALT+W`), quick-info notify (`SUPER CTRL ALT+T`/`B`), transcode (`SUPER CTRL+.`), share menu (`SUPER CTRL+S`). None in marchyo.
7. **Notification silencing / DND** — omarchy `SUPER CTRL+,` toggle + indicator, invoke/restore-last. Marchyo has dismiss-last/all only, no DND, no indicator.
8. **Universal clipboard copy/paste/cut** — omarchy `SUPER+C/V/X` work in terminals too (`sendshortcut`). Marchyo: none (only cliphist watchers + Vicinae history).
9. **Connectivity control menus** — omarchy `SUPER CTRL+A/B/W` → audio/bluetooth/wifi menus. Marchyo approximates via waybar clicks to TUIs (present-but-different, bar-only).
10. **Web-app (PWA) system** — omarchy: `omarchy-webapp-install/-remove`, custom icons, HEY/Zoom handlers, dedicated binds (`SUPER SHIFT+A` ChatGPT, `+C` HEY Calendar, `+E` HEY Email, `+Y` YouTube, `SUPER SHIFT ALT+G` WhatsApp, `+P` Photos, `+X` X). Marchyo's `webapps.nix` is off by default, fewer apps, no icons, no binds.
11. **Display/monitor runtime controls** — monitor scaling cycle (`SUPER+/`), toggle laptop display/mirror (`SUPER CTRL+Delete`/`+ALT+Delete`), lid-switch auto-management. Marchyo: hyprmon TUI + kanshi, no hotkeys.
12. **Misc launches** — tmux "Work" session (`SUPER ALT+RETURN`), nautilus-at-cwd (`SUPER ALT SHIFT+F`), docker TUI (lazydocker, `SUPER SHIFT+D`), font picker. Marchyo: none of these binds (fonts fixed via Stylix).
13. **System-integration extras** — first-run onboarding + About dialog, hooks system (`battery-low`/`theme-set`/`post-boot` drop-ins), hardware quirk scripts (`omarchy-hw-*`; marchyo delegates to `nixos-hardware`), gaming install helpers.

## A3. Present-but-DIFFERENT

| Capability | Omarchy | Marchyo |
|---|---|---|
| Launcher | Walker + Elephant, `SUPER+SPACE` | Vicinae, `SUPER+R` |
| Emoji picker | Walker symbols, `SUPER CTRL+E` | Vicinae, `SUPER+period` |
| Clipboard history | Walker, `SUPER CTRL+V` | Vicinae, `SUPER CTRL+V` (same combo) |
| Color picker | hyprpicker, `SUPER+PRINT` | hyprpicker, `SUPER SHIFT+C` |
| Screen recording | menu, `ALT+PRINT` | `marchyo-screenrecord-toggle`, `SUPER ALT+PRINT` |
| Screenshot | `PRINT` | `PRINT` / `SUPER+S` (grimblast + satty) |
| Connectivity | dedicated menus (`SUPER CTRL+A/B/W`) | waybar clicks → TUIs |
| Theme switch | runtime picker, 19 themes | `marchyo.theme.variant` option, 1 theme |
| Wallpaper | swaybg + picker/cycler | awww daemon, single theme-tied image |
| Update surface | `omarchy-update` menu + waybar indicator | `nixos-rebuild` + `dix` diff, `marchyo` CLI |
| Login / Boot | SDDM / Limine | greetd + tuigreet / systemd-boot |

**Already at parity** (same tool/behavior): mako, voxtype dictation (incl. F9 PTT + `SUPER CTRL+X`), hyprsunset nightlight (`SUPER CTRL+N`), idle-lock toggle (`SUPER CTRL+I`), cursor zoom (`SUPER CTRL+Z`), toggle top bar (`SUPER SHIFT+SPACE`), keybindings cheatsheet (`SUPER+K`), OCR, notification dismiss (`SUPER+,`), window grouping/tiling, hyprlock, hypridle.

## A4. Where marchyo goes BEYOND omarchy

- **Self-tracking stack** — ActivityWatch, auditd + Laurel → Vector → DuckDB/Loki, wakapi, git-activity, weekly org-mode reports, optional local-LLM insights.
- **BYOK AI desktop** — OpenRouter routing buckets, aichat/pi/claude-code, OpenViking context, MCP (mcp-nixos), Agent Skills.
- **Reproducibility & multi-platform** — one flake builds NixOS + nix-darwin + nix-on-droid; declarative rollback; disko/installer ISOs.
- **Editor integration** — jotain (Jylhis Emacs) as first-class default with daemon + Hyprland wiring.
- **Performance module** — declarative kernel/sysctl/IO tuning.

## A5. Omarchy surface that is N/A under NixOS

Not gaps — replaced by the declarative model: `omarchy-install-*`, `-remove-*`, `-pkg-*`, `-update-*`, `-migrate`, `-reinstall`, `-refresh-*` (config regen), channel switching (Stable/RC/Edge/Dev), firmware menu, `-sudo-passwordless`. All map to editing Nix modules + `nixos-rebuild`. Marchyo's `marchyo`/`marchyoctl` CLI + `dix` diff cover the "what changed / rebuild" slice.

---

# PART B — Implementation plan (selected scope)

## Selected scope

From Part A, the following were selected for porting. **Weather** and the **runtime font picker** were explicitly dropped.

- **Quick wins:** power/session menu, SwayOSD overlay, DND toggle + indicator, universal clipboard.
- **Big features:** central system menu, web-app parity, runtime light/dark switch, screensaver.
- **Utilities:** reminders, quick-info notify, transcode + share.
- **Small binds:** monitor controls, app-launch binds, connectivity keybinds.

## Conventions

Built the marchyo way: `writeShellApplication` helpers (the `modules/home/window-toggles.nix` pattern), Hyprland binds in `modules/home/hyprland.nix`, waybar segments following the streaming `custom/voxtype` pattern in `modules/home/waybar.nix`, options under `modules/nixos/options/`, and an eval test per feature under `tests/eval/`. Menus use `gum`/`fzf` in a floating ghostty (`--class=org.omarchy.terminal`, already covered by the `floating-window` rule) — matching the existing `marchyo-keybindings` cheatsheet, not a new GUI toolkit. The TUI aesthetic is preserved; omarchy's transparency/gap toggles are intentionally excluded. New gating options default **on** when `marchyo.desktop.enable` (each opt-out), matching the dictation UI-suboption convention.

Verified facts: `swayosd` is a **package only** (no NixOS/HM module → wire the server as a Home Manager `systemd.user.services` unit + call `swayosd-client` from binds); `terminaltexteffects` (the `tte` binary) is packaged.

**Nix module conventions to follow** (from the `jylhis-nix` skill):
- **Options (RFC 72):** `description` is plain-string Markdown — no `lib.mdDoc`. Use `lib.mkEnableOption` for truly opt-in switches; for the desktop-cascade opt-outs mirror the dictation pattern (`mkOption { type = types.bool; default = true; }` + `lib.mkIf (desktopEnabled && cfg.enable)`). Expose overridable packages with `lib.mkPackageOption pkgs "swayosd" { }` / `"terminaltexteffects"` and the webapp browser, so consumers can swap them.
- **Settings (RFC 42):** any generated config file (mako mode block, swayosd flags, webapp desktop entries) goes through typed attrsets / the module's `settings`, not stringly-typed blobs where a structured option already exists.
- **Home Manager service (SwayOSD):** declare `systemd.user.services.swayosd` with `Unit.Description`, `Service.ExecStart = "${cfg.package}/bin/swayosd-server"`, `Service.Restart = "on-failure"`, and `Install.WantedBy = [ "graphical-session.target" ]` (plus `Unit.PartOf = [ "graphical-session.target" ]`) rather than a bare `exec-once`, so it restarts with the session. (No `swayosd` HM/NixOS module exists — this is hand-rolled.)
- **Priorities:** keep `lib.mkDefault` on consumer-overridable values (e.g. the new keybinds and `webapps.enable`), reserve `lib.mkForce` for the deliberate `SUPER, V` → `SUPER, T` remap if it must override an existing bind.
- Darwin note: option *declarations* under `modules/nixos/options/` are imported by the curated darwin set too, so declaring these Linux-desktop options there is fine as long as all *config* stays in the desktop-gated NixOS/home modules (which darwin never imports) — same as dictation today.

## Keybind map (conflict-resolved)

| Bind | Action | Note |
|---|---|---|
| `SUPER, Escape` | Power/session menu | free |
| `SUPER ALT, Space` | Central system menu | free |
| `SUPER, T` | **Toggle floating** (moved from `SUPER, V`) | frees V; omarchy parity |
| `SUPER, C` / `SUPER, V` / `SUPER, X` | Universal copy/paste/cut | via `sendshortcut`; V freed above |
| `SUPER CTRL, comma` | DND toggle | was "dismiss all" |
| `SUPER CTRL SHIFT, comma` | Dismiss all notifications | moved off `SUPER CTRL, comma` |
| `SUPER CTRL, R` / `+ALT, R` / `+SHIFT, R` | Reminder set / show / clear | free |
| `SUPER CTRL ALT, T` / `+B` | Notify datetime / battery | free |
| `SUPER CTRL, period` | Transcode menu | free |
| `SUPER, backslash` | Monitor scaling cycle | Super+/ kept for password manager |
| `SUPER CTRL, Delete` | Toggle laptop display | Ctrl+Alt+Del stays poweroff |
| `SUPER ALT, Return` | tmux "Work" session | omarchy parity |
| `SUPER ALT, D` | lazydocker | Super+Shift+D stays "Drawer" |
| `SUPER ALT SHIFT, F` | Nautilus at terminal cwd | omarchy parity |
| `SUPER CTRL, A` / `+B` / `+W` | Audio / Bluetooth / Wifi TUI | reuse waybar-click commands |

Share and screensaver get **no dedicated bind** (reached via the central menu / idle) to avoid the crowded `S` cluster in `screenshot.nix`. The `SUPER, V` → `SUPER, T` remap is a user-facing behavior change worth a CHANGELOG/CLAUDE.md note.

## Phase 1 — Quick wins

- **Power/session menu** — new `modules/home/menus.nix` shipping `marchyo-power-menu` (`gum choose` in floating ghostty): Lock (`hyprlock`), Suspend (`systemctl suspend`), Hibernate (`systemctl hibernate`), Logout (`uwsm stop` / `loginctl terminate-user`), Reboot, Shutdown. Bind `SUPER, Escape`.
- **SwayOSD** — new `modules/home/swayosd.nix`: install `cfg.package` (`mkPackageOption pkgs "swayosd"`), run `swayosd-server` as a Home Manager `systemd.user.services.swayosd` unit (`WantedBy`/`PartOf` = `graphical-session.target`, `Restart = "on-failure"`), rewrite the `bindel`/media binds in `hyprland.nix` to call `swayosd-client --output-volume raise|lower|mute-toggle`, `--input-volume mute-toggle`, `--brightness raise|lower`. Gate `marchyo.osd.enable` (default-on when desktop).
- **DND toggle + indicator** — extend `modules/home/mako.nix` with `[mode=do-not-disturb] invisible=1`; add `marchyo-dnd-toggle` (`makoctl mode -t do-not-disturb`) to `window-toggles.nix`; add a `custom/dnd` waybar segment (signal-refreshed, styled like `custom/voxtype`). Binds per table.
- **Universal clipboard** — in `hyprland.nix` add `bind = SUPER, C, sendshortcut, CTRL, C,` (+ SHIFT+Insert paste, CTRL+X cut); remap toggle-floating `SUPER, V` → `SUPER, T` first.

## Phase 2 — Menus & launches

- **Central system menu** — `marchyo-menu` in `modules/home/menus.nix`: hierarchical `gum`/`fzf` menu bound `SUPER ALT, Space`. **Trigger** (screenshot, screenrecord toggle, color pick, transcode, share), **Setup** (audio→wiremix/pavucontrol, wifi→impala, bluetooth→bluetui, monitors→hyprmon, power-profile→`powerprofilesctl`), **Style** (light/dark toggle → Phase 6), **System** (→ power menu), **Learn** (→ `marchyo-keybindings`, doc URLs). Gate `marchyo.menus.enable`.
- **Connectivity keybinds** — `hyprland.nix` binds `SUPER CTRL, A/B/W` launching the existing floating TUIs (reuse waybar `on-click` commands).
- **App-launch binds** — `SUPER ALT, Return` (tmux `new -A -s Work`), `SUPER ALT, D` (lazydocker; add to dev tooling), `SUPER ALT SHIFT, F` (nautilus at cwd).
- **Monitor controls** — `marchyo-monitor-scale-cycle` and `marchyo-laptop-display-toggle` in `window-toggles.nix`; binds `SUPER, backslash` and `SUPER CTRL, Delete`.

## Phase 3 — Utilities

- **Reminders** — `marchyo-reminder` (gum prompt → `systemd-run --user --on-active … notify-send`; list in `$XDG_STATE_HOME/marchyo/reminders`). Binds `SUPER CTRL, R`/`+ALT`/`+SHIFT`. Gate `marchyo.reminders.enable`.
- **Quick-info notify** — `marchyo-notify-datetime`, `marchyo-notify-battery` (notify-send wrappers). Binds `SUPER CTRL ALT, T`/`B`.
- **Transcode + share** — `marchyo-transcode` (ffmpeg + gum format menu, ascii variant via `tte`) bound `SUPER CTRL, period`; `marchyo-share` (clipboard/file/folder → copy path; upload target = follow-up decision) reached from the central menu.

## Phase 4 — Web-app parity

Extend `modules/home/webapps.nix` + `modules/nixos/options/webapps.nix`: more apps (ChatGPT, HEY Calendar/Email, YouTube, WhatsApp, Photos, X, GitHub, Discord, Zoom), ship/generate icons, default `marchyo.webapps.enable = mkDefault true` when desktop is on, and have `webapps.nix` inject `wayland.windowManager.hyprland.settings.bind` entries (`SUPER SHIFT, A/C/E/Y`, `SUPER SHIFT ALT, G`, …). List-valued Hyprland settings merge across HM modules, so no edit to `hyprland.nix` is needed.

## Phase 5 — Screensaver

`marchyo-screensaver` runs `tte` (`pkgs.terminaltexteffects`) in a floating ghostty `--class=org.omarchy.screensaver` (existing `Screensaver` fullscreen rule matches). Add a `hypridle` listener (~150s) that launches it when hyprlock isn't running, plus a central-menu Trigger entry. Gate `marchyo.screensaver.enable`.

## Phase 6 — Runtime light/dark switch (largest lift)

Marchyo's variant is build-time (Stylix). True runtime switch without a rebuild:
1. Generate **both** palette/asset sets at build time (extend `modules/generic/jylhis-palette.nix` / `theme.nix` to emit dark **and** light variants + both wallpapers from `packages/marchyo-wallpapers/`).
2. `marchyo-theme-toggle` swaps an active symlink (`~/.config/marchyo/current-theme`), sets the awww wallpaper, reloads live surfaces: waybar (restart unit), mako (`makoctl reload`), ghostty (config reload), Hyprland colors (`hyprctl reload`/`keyword`), hyprlock colors; persists the choice.
3. Wire into the central-menu **Style** branch and an optional bind.

Aligns with the recorded near-future dynamic-theme goal (keep awww, not swaybg). Biggest, least-mechanical item — build Phases 1–5 first and give Phase 6 its own design/review pass (it touches the theming source-of-truth in CLAUDE.md).

## Testing / verification

- **Eval tests:** add `tests/eval/omarchy-extras.nix` (or per-feature files) asserting configs with each new `marchyo.{osd,menus,reminders,screensaver,webapps}.enable` evaluate cleanly; extend a webapps/theme test for bind injection and dual-variant assets. Auto-discovered from `tests/eval/`.
- **Gates:** `just check` (nix flake check + statix + deadnix) and `just fmt` must pass — CI-enforced.
- **End-to-end (VM via `just run`):** verify each new keybind fires, SwayOSD shows on volume/brightness, DND silences + indicator flips, power menu actions work, central menu navigates, web-app binds open PWAs, screensaver triggers on idle, and (Phase 6) the theme toggle flips light/dark live without a rebuild.
- Follow the `nix-development` skill's module conventions; document new options in `CLAUDE.md` and `docs/configuration/`.

## Key files

- **New:** `modules/home/menus.nix`, `modules/home/swayosd.nix`, options `modules/nixos/options/{osd,menus,reminders,screensaver}.nix` (or one shared file), `tests/eval/omarchy-extras.nix`.
- **Modified:** `modules/home/hyprland.nix` (binds + Super+V→T remap + swayosd media binds), `modules/home/window-toggles.nix` (new helper scripts), `modules/home/waybar.nix` (`custom/dnd`), `modules/home/mako.nix` (dnd mode), `modules/home/webapps.nix` + `modules/nixos/options/webapps.nix`, `modules/generic/{jylhis-palette,theme}.nix` (Phase 6 dual variants), `CLAUDE.md` + `docs/`.
