# Captive-portal sign-in window: a floating, centered 900x760 web-app window
# opened by `marchyo network portal`, plus the config file that command reads.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  mc = osConfig.marchyo or { };
  check = (mc.network or { }).connectivityCheck or { };
  enabled =
    pkgs.stdenv.hostPlatform.isLinux && (mc.desktop.enable or false) && (check.enable or false);

  browser = import ../../lib/webapp-browser.nix { inherit osConfig; };
  hostMatch = builtins.match "[a-zA-Z][a-zA-Z0-9+.-]*://([^/:?#]+).*" (check.uri or "");
  host = if hostMatch == null then "" else builtins.head hostMatch;
  # Chromium names an --app window `chrome-<host>__<path>-Default` (brave-...).
  windowClass = "^(chrome|brave)-${builtins.replaceStrings [ "." ] [ "[.]" ] host}__.*$";
in
{
  config = lib.mkIf (enabled && host != "") {
    home.packages = lib.optional browser.needsChromium pkgs.chromium;

    xdg.configFile."marchyo/captive-portal.json".text = builtins.toJSON {
      inherit (check) uri;
      browser = browser.command;
    };

    wayland.windowManager.hyprland.settings.window_rule = [
      {
        match.class = windowClass;
        float = true;
        center = true;
        size = [
          900
          760
        ];
      }
    ];
  };
}
