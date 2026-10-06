# Marchyo TODO

Open work only: delete an item in the commit that finishes it. The
authoritative description of the shell is [`shell/README.md`](shell/README.md).

Out of scope, not wanted: a dashboard panel and a calendar panel.

New panels get a `marchyo shell` verb, a bind and `doctor` coverage on
arrival.

## 1. Theming

- **Base16 roles that need upstream values (`pkgs.jylhis-design-src`).**
  `tokenSlots` (`lib/theme-generators.nix`) maps each token to the base16
  slot the styling guidelines name for its role, so scheme themes collapse
  `accent-hover` and `syn-number` onto `accent`, `border`/`syn-comment` onto
  `text-faint`, `border-strong` onto `text-muted`, `accent-subtle` onto
  `bg-subtle`, `selection-bg` onto `surface`, and `destructive`/`syn-variable`
  onto `status-err`. `contour`, `decorator`, `scrim` and `syn-docstring` have
  no base16 role and keep the Jylhis hex. A real fix needs a Jylhis extension
  or base24-style export upstream. The reference exports in
  `platforms/_reference/base16` have also drifted from `themes/jylhis.json`
  (field base01; sheet base09 to base0E).

Rules for any new theme surface:

- Emit it from the single palette source in all three places that build a
  theme dir: `theme-runtime.nix` (Jylhis pair), its `mkSchemeThemeDir`
  (catalog/inline), and the CLI `generateThemeChangeBase` (matugen); the
  relink/reload leg goes in `activateThemeDir`.
- Stay IFD-free: pure string templating from `palette.hex` / base16 slots,
  never `readFile` of a built derivation such as `pkgs.jylhis-themes`
  (referencing it as a path is fine).
- Add a `testNixOS` assertion in `tests/eval/themes.nix` and update
  `site/src/content/docs/docs/configuration/theming.mdx`.
- If a surface needs a role with no palette token, report it as a
  `pkgs.jylhis-design-src` gap instead of inventing it locally.
- The swaps lean on conventions nothing else enforces: HM renders
  `services.mako.settings` into `xdg.configFile."mako/config"`,
  `programs.waybar.style` is a string, and GTK reads
  `design:platforms/gtk/jylhis-<mode>.css`. Recheck them on HM or design bumps.

## 2. Shell

### Compositor effects

- Optional CRT `screen_shader` in `modules/home/hyprland.nix` if a retro
  theme appears.

### Discrete stack removal (later milestone)

Vicinae, waybar, mako, SwayOSD and hyprlock stay as the
`marchyo.shell.enable = false` fallback until the shell is the only path.

## 3. Features

- **Omarchy extras, low priority:** lifecycle hooks (`battery-low`,
  `theme-set`, `post-boot`), first-run onboarding, crash capture, per-theme
  keyboard RGB and backgrounds, dropbox/speedtest panels. Each needs a
  declarative shape (module/timer) first.

## Won't do

- omarchy's update/migrate/refresh engine, AUR tooling, `omarchy-install-*`:
  replaced by `nixos-rebuild` + `flake.lock` + generations.
- Runtime plugin fetch/enable: plugins stay Nix-declared and baked.
- Dev-environment installers (mise etc.): per-project devenv.
- Per-model kernel patches (expose the kernel package choice instead), a
  Windows VM, omarchy's server edition.
- Plymouth runtime theming: never on screen during a session.
- Material You as default, transparency/blur/glass shell modes.

## Shell constraints (keep when touching `shell/`)

- `Bar/` owns no runtime state: every `Process`/`Timer`/`Connections`/
  `FileView`/`Socket` lives in a `Services/` singleton (contract-tested).
- Exactly one IPC mechanism, the `IpcHandler { target: "shell" }` in
  `shell.qml`; compat-shim handlers use per-plugin targets.
- Long-lived streams restart with backoff keyed on `onRunningChanged` (see
  `Services/Dictation.qml`); a dead stream reports in the tooltip.
- Every `Config.<tool>` is declared in `Commons/Config.qml` and baked by
  `packages/marchyo-shell/package.nix` (contract-tested).
- Bound subprocess output with a `maxChars` ceiling.
- Never point a `FileView` at a user-writable file; watch the directory as a
  doorbell (`preload: false`).
- Sandbox probes check the Wayland socket, not `WAYLAND_DISPLAY`.
- Disable `Behavior`s before a construction-time jump to 0 and re-enable
  `onFinished`, never `onStopped`.
- Nerd Font glyphs get stripped by editing tools: targeted edits only in `Bar/`.

## Process

- Verification stops at `nix build` / `nix flake check`; activating the running
  system is the user's action.
- Every new module/option gets a `testNixOS` eval test; option declarations
  stay platform-neutral (Darwin eval gate); keep
  `site/src/content/docs/docs/configuration/` in sync.
- `just fmt` + `just check` before each commit; conventional commits.

## References

- [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell): IPC CLI, plugins + lockfile, control center. Primary reference.
- [caelestia-dots/shell](https://github.com/caelestia-dots/shell): launcher providers, per-monitor config, closest services split.
- [serpantinum](https://github.com/ilyamiro/serpantinum): typed Nix options module, CLI-as-IPC.
- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (`ii/` only): overview, quick-toggle models, fuzzysort, cliphist previews.
- [qylock](https://github.com/Darkkal44/qylock): lock-screen UX (skip its SDDM shim).
- [flickowoa yorha](https://github.com/flickowoa/dotfiles/tree/hyprland-yorha): compositor effects.
- [linux-retroism](https://github.com/diinki/linux-retroism), [rumda](https://github.com/Nytril-ark/rumda): readable reference QML.
- [ekremx25/quickshell](https://github.com/ekremx25/quickshell): notification centre.
- [awesome-quickshell](https://github.com/ziuus/awesome-quickshell): landscape index.
