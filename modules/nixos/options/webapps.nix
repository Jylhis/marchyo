{ lib, ... }:
let
  inherit (lib) mkOption types;

  appType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "Display name shown in launchers (also used, slugified, as the .desktop id).";
      };
      url = mkOption {
        type = types.str;
        example = "https://chatgpt.com/";
        description = "URL opened in the browser's standalone app mode (`--app=`).";
      };
      icon = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Icon name (freedesktop theme) or absolute path. Defaults to a generic web icon.";
      };
    };
  };
in
{
  options.marchyo.webapps = {
    enable = lib.mkEnableOption ''
      web apps as standalone desktop windows. Generates freedesktop `.desktop`
      entries that launch a chromium-family browser with `--app=<url>`, so a
      site opens as its own window (no tabs/chrome). Requires the desktop
      feature. If the selected `marchyo.defaults.browser` is not chromium-based
      (e.g. firefox), chromium is pulled in for app mode'';

    browser = mkOption {
      type = types.nullOr (
        types.enum [
          "brave"
          "google-chrome"
          "chromium"
        ]
      );
      default = null;
      description = ''
        Chromium-family browser used to launch web apps. `null` follows
        `marchyo.defaults.browser` when it is chromium-based, otherwise falls
        back to chromium.
      '';
    };

    apps = mkOption {
      type = types.listOf appType;
      default = [
        {
          name = "ChatGPT";
          url = "https://chatgpt.com/";
        }
        {
          name = "GitHub";
          url = "https://github.com/";
        }
        {
          name = "YouTube";
          url = "https://youtube.com/";
        }
        {
          name = "WhatsApp";
          url = "https://web.whatsapp.com/";
        }
        {
          name = "Discord";
          url = "https://discord.com/channels/@me";
        }
        {
          name = "Zoom";
          url = "https://app.zoom.us/wc/home";
        }
      ];
      description = ''
        Web apps to register. Each becomes a `.desktop` entry launching the
        browser in app mode. Override the whole list to customise; the default
        mirrors a common omarchy subset. Only used when `enable = true`.
      '';
    };
  };
}
