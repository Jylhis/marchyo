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
      key = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "A";
        description = ''
          Hyprland key (the part after the modifiers) that launches this app.
          `null` binds no key. Pick one free of marchyo's existing SUPER+SHIFT
          binds (C, D, H, I, O, S are taken, plus workspace digits/arrows/Tab).
        '';
      };
      modifiers = mkOption {
        type = types.str;
        default = "SUPER SHIFT";
        example = "SUPER SHIFT ALT";
        description = "Hyprland modifier chord prefixing `key`.";
      };
    };
  };
in
{
  options.marchyo.webapps = {
    enable = lib.mkEnableOption ''
      web apps as standalone desktop windows. Generates freedesktop `.desktop`
      entries that launch a chromium-family browser with `--app=<url>`, so a
      site opens as its own window (no tabs/chrome), plus a Hyprland keybinding
      for every app that declares a `key` (omarchy-style, default SUPER+SHIFT).
      Requires the desktop feature. If the selected `marchyo.defaults.browser`
      is not chromium-based (e.g. firefox), chromium is pulled in for app mode'';

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
          key = "A";
        }
        {
          name = "GitHub";
          url = "https://github.com/";
          key = "G";
        }
        {
          name = "YouTube";
          url = "https://youtube.com/";
          key = "Y";
        }
        {
          name = "WhatsApp";
          url = "https://web.whatsapp.com/";
          key = "W";
        }
        {
          # No default key: SUPER+SHIFT+D is the scratchpad move bind.
          name = "Discord";
          url = "https://discord.com/channels/@me";
        }
        {
          name = "Zoom";
          url = "https://app.zoom.us/wc/home";
          key = "Z";
        }
      ];
      description = ''
        Web apps to register. Each becomes a `.desktop` entry launching the
        browser in app mode; entries with a `key` also get a Hyprland
        keybinding (omarchy-style, default chord SUPER+SHIFT). Override the whole
        list to customise; the default mirrors a common omarchy subset. Only used
        when `enable = true`.
      '';
    };
  };
}
