# marchyo.keyboard.fnMode, keyboard.backlight and composeKey = "shift-caps".
{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) hyprHasBind;

  modprobe = c: c.boot.extraModprobeConfig;
  hm = c: c.home-manager.users.testuser;
  binds = c: (hm c).wayland.windowManager.hyprland.settings.bind or [ ];
  kbOptions = c: (hm c).home.keyboard.options;
  hyprEnv = c: (hm c).wayland.windowManager.hyprland.settings.env;
  uwsmEnv = c: (hm c).xdg.configFile."uwsm/env-hyprland".text or "";

  xkb = (import ../../lib/xkb-compose.nix).tree pkgs;
in
{
  refs = {
    desktop = {
      eval-keyboard-fnmode-default-untouched =
        c:
        helpers.expect (
          !(lib.hasInfix "hid_apple" (modprobe c))
        ) "fnMode = null must not write modprobe options";

      eval-keyboard-backlight-binds =
        c:
        helpers.expect (
          hyprHasBind (binds c) "XF86KbdBrightnessUp" "brightness --keyboard up"
          && hyprHasBind (binds c) "XF86KbdBrightnessDown" "brightness --keyboard down"
          && hyprHasBind (binds c) "XF86KbdLightOnOff" "brightness --keyboard toggle"
          && hyprHasBind (binds c) "CTRL + XF86MonBrightnessUp" "brightness --keyboard up"
          && hyprHasBind (binds c) "CTRL + XF86MonBrightnessDown" "brightness --keyboard down"
        ) "keyboard backlight binds missing";

      # The default compose key is "menu", so the plain desktop doubles as the
      # explicit composeKey = "menu" configuration.
      eval-keyboard-menu-compose-unchanged =
        c:
        helpers.expect (
          lib.elem "compose:menu" (kbOptions c) && !(c.environment.etc ? xkb)
        ) "the menu compose key must stay on the stock option";

      # The menu compose key writes no uwsm session env.
      eval-keyboard-shift-caps-session-env-menu =
        c: helpers.expect (uwsmEnv c == "") "the menu compose key must leave the uwsm session env alone";

      eval-keyboard-compose-default-menu =
        c:
        helpers.expect (
          c.marchyo.keyboard.composeKey == "menu"
          && lib.elem "compose:menu" (kbOptions c)
          && !(c.environment.etc ? xkb)
        ) "the default compose key must be the Menu key";
    };

    # desktop-tweaks: fnMode = "media".
    desktop-tweaks.eval-keyboard-fnmode-media =
      c:
      helpers.expect (
        lib.hasInfix "options hid_apple fnmode=1" (modprobe c)
        && lib.hasInfix "options hid_asus fnlock_default=0" (modprobe c)
        && lib.hasInfix "options asus_wmi fnlock_default=0" (modprobe c)
      ) "media mode should set fnmode=1 and fnlock_default=0";

    # desktop-tweaks-2: fnMode = "function".
    desktop-tweaks-2.eval-keyboard-fnmode-function =
      c:
      helpers.expect (
        lib.hasInfix "options hid_apple fnmode=2" (modprobe c)
        && lib.hasInfix "options hid_asus fnlock_default=1" (modprobe c)
        && lib.hasInfix "options asus_wmi fnlock_default=1" (modprobe c)
      ) "function mode should set fnmode=2 and fnlock_default=1";

    desktop-off.eval-keyboard-backlight-disabled =
      c:
      helpers.expect (
        !(hyprHasBind (binds c) "XF86KbdBrightnessUp" "brightness")
      ) "backlight.enable = false must drop the binds";

    # desktop-tweaks-3: composeKey = "shift-caps".
    desktop-tweaks-3 = {
      eval-keyboard-shift-caps-options =
        c:
        helpers.expect (
          lib.elem "marchyo:shift_caps_compose" (kbOptions c)
          && !(lib.any (lib.hasPrefix "compose:") (kbOptions c))
          && c.environment.sessionVariables.XKB_CONFIG_EXTRA_PATH == "/etc/xkb"
          && c.environment.etc ? xkb
          && !(lib.hasInfix "shift_caps" c.services.xserver.xkb.options)
        ) "shift-caps should reach Hyprland only, with the extra path exported";

      # Hyprland only resolves the option with XKB_CONFIG_EXTRA_PATH set, so the
      # Hyprland env and uwsm's session env carry it too.
      eval-keyboard-shift-caps-session-env =
        c:
        helpers.expect (
          hyprHasBind (hyprEnv c) "XKB_CONFIG_EXTRA_PATH" "/etc/xkb"
          && lib.hasInfix "XKB_CONFIG_EXTRA_PATH=/etc/xkb" (uwsmEnv c)
        ) "XKB_CONFIG_EXTRA_PATH must reach the Hyprland and uwsm session env with shift-caps";
    };

    # A Caps Lock remap keeps the Menu compose key (desktop-tweaks:
    # options = [ "ctrl:swapcaps" ]).
    desktop-tweaks.eval-keyboard-caps-remap-keeps-menu-compose =
      c:
      helpers.expect (
        c.marchyo.keyboard.composeKey == "menu"
        && lib.elem "compose:menu" (kbOptions c)
        && !(lib.elem "marchyo:shift_caps_compose" (kbOptions c))
      ) "a Caps Lock remap must keep the menu compose key";
  };

  refConfig = {
    desktop-tweaks.marchyo.keyboard = {
      fnMode = "media";
      options = [ "ctrl:swapcaps" ];
    };
    desktop-tweaks-2.marchyo.keyboard.fnMode = "function";
    desktop-tweaks-3.marchyo.keyboard.composeKey = "shift-caps";
    desktop-off.marchyo.keyboard.backlight.enable = false;
  };

  # misconfigured: shift-caps compose with a Caps Lock remap.
  failing.eval-keyboard-caps-remap-shift-caps-rejected = {
    on = "misconfigured";
    expect = ''composeKey = "shift-caps" redefines Caps Lock'';
  };

  failingConfig.misconfigured.marchyo.keyboard = {
    options = [ "ctrl:swapcaps" ];
    composeKey = "shift-caps";
  };

  # libxkbcommon resolves the custom option against the generated tree: Caps
  # Lock keeps Caps_Lock on level 1 and Shift+Caps Lock yields Multi_key. A
  # small build (no NixOS evaluation), kept in the default checks.
  checks.eval-keyboard-shift-caps-xkbcli =
    pkgs.runCommand "eval-keyboard-shift-caps-xkbcli"
      {
        nativeBuildInputs = [ pkgs.libxkbcommon ];
      }
      ''
        export XKB_CONFIG_EXTRA_PATH=${xkb}
        xkbcli compile-keymap --layout us --options marchyo:shift_caps_compose > keymap.xkb
        grep -q 'symbols\[1\]= \[ *Caps_Lock, *Multi_key \]' keymap.xkb
        touch $out
      '';
}
