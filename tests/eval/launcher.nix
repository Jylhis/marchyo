# Vicinae launcher wiring (marchyo.launcher.*).
#
# The first two tests are regressions, not hypotheticals: marchyo shipped
# `settings.window.*` and `settings.font.size` for a while, and Vicinae ignores
# unknown config keys silently instead of failing, so the intended square
# corners and font size never applied and nothing noticed. Any future rename
# back to those spellings must fail here.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  cfgFor =
    extra:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    }).config;

  hmFor = extra: (cfgFor extra).home-manager.users.testuser;

  cfg = cfgFor { };
  hm = hmFor { };
  vicinae = hm.programs.vicinae;
  inherit (vicinae) settings;
in
{
  # Defect 1: the window block is `launcher_window`. A top-level `window` key is
  # dead config that the daemon drops on the floor.
  eval-launcher-window-key = pkgs.writeText "eval-launcher-window-key" (
    if settings ? window then
      throw "FAIL: settings.window is not a Vicinae config key — the window block is `launcher_window`; it was silently ignored"
    else if !(settings ? launcher_window) then
      throw "FAIL: settings.launcher_window is missing"
    else if settings.launcher_window.rounding != 0 then
      throw "FAIL: launcher_window.rounding should be 0 (square corners), got ${toString settings.launcher_window.rounding}"
    else if settings.launcher_window.opacity != 1.0 then
      throw "FAIL: launcher_window.opacity should be 1.0 (opaque)"
    else if settings.launcher_window.material != "none" then
      throw "FAIL: launcher_window.material should be \"none\" — \"auto\" lets the compositor blur an opaque window"
    else
      "pass"
  );

  # Defect 2: the font size lives at `font.normal.size`; a bare `font.size` is
  # dead config. Also pins the fontScale wiring, which nothing else covered.
  eval-launcher-font-key =
    let
      scaled = (hmFor { marchyo.theme.fontScale = 2.0; }).programs.vicinae.settings;
    in
    pkgs.writeText "eval-launcher-font-key" (
      if settings.font ? size then
        throw "FAIL: settings.font.size is not a Vicinae config key — the size lives at `font.normal.size`; it was silently ignored"
      else if !(settings.font ? normal) then
        throw "FAIL: settings.font.normal is missing"
      else if settings.font.normal.family != "Hanken Grotesk" then
        throw "FAIL: font.normal.family should be the v2 body face, got ${settings.font.normal.family}"
      else if scaled.font.normal.size != 24 then
        throw "FAIL: font.normal.size should track marchyo.theme.fontScale (expected 24 at scale 2.0, got ${toString scaled.font.normal.size})"
      else
        "pass"
    );

  # emacs navigation binds Ctrl+N/Ctrl+P, which collide head-on with Vicinae's
  # stock action.new (control+N) and open-search-filter (control+P). Switching
  # the scheme without remapping those two leaves the launcher ambiguous.
  eval-launcher-keybinding =
    let
      vim = (hmFor { marchyo.launcher.keybinding = "vim"; }).programs.vicinae.settings;
    in
    pkgs.writeText "eval-launcher-keybinding" (
      if settings.keybinding != "emacs" then
        throw "FAIL: keybinding should default to emacs, got ${settings.keybinding}"
      else if settings.keybinds."action.new" == "control+N" then
        throw "FAIL: action.new still on control+N, which is navigate-down in emacs mode"
      else if settings.keybinds."open-search-filter" == "control+P" then
        throw "FAIL: open-search-filter still on control+P, which is navigate-up in emacs mode"
      else if vim.keybinding != "vim" then
        throw "FAIL: marchyo.launcher.keybinding should reach settings.keybinding"
      else if vim ? keybinds then
        throw "FAIL: the emacs collision remaps should not apply to the vim scheme"
      else
        "pass"
    );

  # Upstream posts a system-info payload daily and enables it by default.
  eval-launcher-telemetry =
    let
      on = (hmFor { marchyo.launcher.telemetry.enable = true; }).programs.vicinae.settings;
    in
    pkgs.writeText "eval-launcher-telemetry" (
      if settings.telemetry.system_info != false then
        throw "FAIL: telemetry.system_info should default off"
      else if on.telemetry.system_info != true then
        throw "FAIL: marchyo.launcher.telemetry.enable should reach settings.telemetry.system_info"
      else
        "pass"
    );

  eval-launcher-declutter =
    let
      loud = (hmFor { marchyo.launcher.declutter = false; }).programs.vicinae.settings;
      hidden = settings.providers.vicinae.entrypoints;
    in
    pkgs.writeText "eval-launcher-declutter" (
      if settings.providers.theme.enabled != false then
        throw "FAIL: the theme provider (Set Theme) should be disabled — marchyo owns theming"
      else if
        lib.any (e: (hidden.${e}.enabled or true) != false) [
          "sponsor"
          "report-bug"
          "about"
        ]
      then
        throw "FAIL: Donate/Report a Bug/About should be hidden from root search"
      else if loud ? providers then
        throw "FAIL: declutter = false should leave providers unset"
      else
        "pass"
    );

  # Both variants are registered so a variant flip needs no theme rebuild, but
  # theme.dark.name and theme.light.name are both pinned to the built variant:
  # Vicinae picks the slot from Qt's reported colour scheme and treats "unknown"
  # as dark, which under Hyprland can disagree with the rest of the desktop.
  eval-launcher-theme =
    let
      light = (hmFor { marchyo.theme.variant = "light"; }).programs.vicinae.settings;
      registered = lib.attrNames vicinae.themes;
    in
    pkgs.writeText "eval-launcher-theme" (
      if
        registered != [
          "jylhis-field"
          "jylhis-sheet"
        ]
      then
        throw "FAIL: both jylhis themes should be registered, got ${toString registered}"
      else if vicinae.themes.jylhis-field.meta ? version then
        throw "FAIL: meta.version is not read by Vicinae's theme parser and is reported as an unused key"
      else if vicinae.themes.jylhis-field.meta.variant != "dark" then
        throw "FAIL: jylhis-field should declare the dark variant"
      else if
        settings.theme.dark.name != "jylhis-field" || settings.theme.light.name != "jylhis-field"
      then
        throw "FAIL: both theme slots should pin the dark theme when variant = dark"
      else if light.theme.dark.name != "jylhis-sheet" || light.theme.light.name != "jylhis-sheet" then
        throw "FAIL: both theme slots should pin the light theme when variant = light"
      else if
        vicinae.themes.jylhis-field.colors.core.background
        == vicinae.themes.jylhis-sheet.colors.core.background
      then
        throw "FAIL: the two variants resolved to the same background — the palette is not variant-aware"
      else
        "pass"
    );

  # Two-sided wiring: the NixOS module installs the setcap wrapper, and the
  # daemon has to be pointed at it because findHelperProgram() only searches
  # store-relative paths and never /run/wrappers/bin. Either half alone is a
  # no-op, so they are asserted together.
  eval-launcher-input-server =
    let
      env = hm.systemd.user.services.vicinae.Service.Environment;
      off = cfgFor { marchyo.launcher.inputServer.enable = false; };
      offEnv = off.home-manager.users.testuser.systemd.user.services.vicinae.Service.Environment;
      hasBinVar = lib.any (lib.hasInfix "VICINAE_INPUT_SERVER_BIN=/run/wrappers/bin/");
    in
    pkgs.writeText "eval-launcher-input-server" (
      if !cfg.programs.vicinae.input-server.enable then
        throw "FAIL: the input-server wrapper should be enabled on a desktop"
      else if cfg.security.wrappers.vicinae-input-server.capabilities != "cap_dac_override+ep" then
        throw "FAIL: the input-server wrapper needs cap_dac_override to write /dev/uinput"
      else if !(hasBinVar env) then
        throw "FAIL: VICINAE_INPUT_SERVER_BIN must point the daemon at the wrapper — it never searches /run/wrappers/bin on its own"
      else if off.programs.vicinae.input-server.enable then
        throw "FAIL: inputServer.enable = false should skip the cap_dac_override wrapper"
      else if hasBinVar offEnv then
        throw "FAIL: without the wrapper the daemon must not be pointed at /run/wrappers/bin"
      else
        "pass"
    );

  # The launcher is opt-out, and a headless host must never grow the capability.
  eval-launcher-opt-out =
    let
      off = cfgFor { marchyo.launcher.enable = false; };
      headless = cfgFor { marchyo.desktop.enable = false; };
    in
    pkgs.writeText "eval-launcher-opt-out" (
      if off.home-manager.users.testuser.programs.vicinae.enable then
        throw "FAIL: marchyo.launcher.enable = false should disable vicinae"
      else if off.programs.vicinae.input-server.enable then
        throw "FAIL: marchyo.launcher.enable = false should skip the input-server wrapper"
      else if headless.programs.vicinae.input-server.enable then
        throw "FAIL: a headless host must not get the cap_dac_override wrapper (upstream defaults it on)"
      else
        "pass"
    );
}
