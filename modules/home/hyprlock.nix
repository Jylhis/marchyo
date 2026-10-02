{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # The unified shell locks in-process (Phase 4); hyprlock stands down under
  # the same mutual-exclusion cutover as waybar/mako/swayosd.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;

  fontScale = if cfg != null then cfg.fontScale else 1.0;
  fs = import ../../lib/font-scale.nix {
    inherit lib;
    scale = fontScale;
  };

  # Colours come from the runtime theme layer's per-theme include (hyprlang
  # `$bg`/`$text`/… vars), sourced first so `marchyo theme set/next` restyles the
  # next lock with no rebuild. See modules/home/theme-runtime.nix
  # (hyprlockColorsFor). Only geometry/fontScale stay build-time here.
  colorsInclude = "${config.xdg.configHome}/marchyo/current-theme/hyprlock-colors.conf";
in
{
  config = mkIf (desktopEnabled && !shellEnabled) {
    programs.hyprlock = {
      enable = true;
      sourceFirst = true;
      settings = mkIf (cfg != null && cfg.enable) {
        source = colorsInclude;

        general = {
          disable_loading_bar = true;
          grace = 10;
          hide_cursor = true;
          ignore_empty_input = true;
          no_fade_in = false;
          no_fade_out = false;
        };

        animations = {
          enabled = true;
        };

        # Gate on the host running fprintd: hyprlock's fprintd backend aborts when
        # the service is missing, breaking the lock screen on readerless desktops.
        auth = {
          "fingerprint:enabled" = osConfig.services.fprintd.enable or false;
        };

        background = [
          {
            monitor = "";
            color = "$bg";
          }
        ];

        label = {
          monitor = "";
          text = "$FPRINTPROMPT";
          text_align = "center";
          color = "$text";
          font_size = fs.round 24;
          font_family = "BlexMono Nerd Font";
          position = "0, -100";
          halign = "center";
          valign = "center";
        };

        input-field = {
          monitor = "";
          size = "600, 100";
          position = "0, 0";
          halign = "center";
          valign = "center";

          outline_thickness = 2;
          outer_color = "$borderStrong";
          inner_color = "$surface";
          font_color = "$text";
          check_color = "$accent";
          fail_color = "$statusErr";

          font_family = "BlexMono Nerd Font";
          font_size = fs.round 32;

          placeholder_text = "  Enter Password";
          fail_text = "<i>$PAMFAIL ($ATTEMPTS)</i>";

          rounding = 0;
          shadow_passes = 0;
          fade_on_empty = false;
        };
      };
    };
  };
}
