# marchyo.keyboard.fnMode, keyboard.backlight and composeKey = "shift-caps".
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind;

  evalWith =
    extra:
    lib.nixosSystem {
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
    };

  verdict =
    name: ok: msg:
    pkgs.writeText "eval-${name}" (if ok then "pass" else throw "FAIL: ${name}: ${msg}");

  modprobe = e: e.config.boot.extraModprobeConfig;
  hm = e: e.config.home-manager.users.testuser;
  binds = e: (hm e).wayland.windowManager.hyprland.settings.bind or [ ];
  kbOptions = e: (hm e).home.keyboard.options;
  hyprEnv = e: (hm e).wayland.windowManager.hyprland.settings.env;
  uwsmEnv = e: (hm e).xdg.configFile."uwsm/env-hyprland".text or "";

  media = evalWith { marchyo.keyboard.fnMode = "media"; };
  fn = evalWith { marchyo.keyboard.fnMode = "function"; };
  shiftCaps = evalWith { marchyo.keyboard.composeKey = "shift-caps"; };
  noBacklight = evalWith { marchyo.keyboard.backlight.enable = false; };
  menu = evalWith { marchyo.keyboard.composeKey = "menu"; };
  default = evalWith { };
  swapCaps = evalWith { marchyo.keyboard.options = [ "ctrl:swapcaps" ]; };
  swapCapsShift = evalWith {
    marchyo.keyboard.options = [ "ctrl:swapcaps" ];
    marchyo.keyboard.composeKey = "shift-caps";
  };

  xkb = (import ../../lib/xkb-compose.nix).tree pkgs;
in
{
  eval-keyboard-fnmode-default-untouched = verdict "keyboard-fnmode-default-untouched" (
    !(lib.hasInfix "hid_apple" (modprobe default))
  ) "fnMode = null must not write modprobe options";

  eval-keyboard-fnmode-media = verdict "keyboard-fnmode-media" (
    lib.hasInfix "options hid_apple fnmode=1" (modprobe media)
    && lib.hasInfix "options hid_asus fnlock_default=0" (modprobe media)
    && lib.hasInfix "options asus_wmi fnlock_default=0" (modprobe media)
  ) "media mode should set fnmode=1 and fnlock_default=0";

  eval-keyboard-fnmode-function = verdict "keyboard-fnmode-function" (
    lib.hasInfix "options hid_apple fnmode=2" (modprobe fn)
    && lib.hasInfix "options hid_asus fnlock_default=1" (modprobe fn)
    && lib.hasInfix "options asus_wmi fnlock_default=1" (modprobe fn)
  ) "function mode should set fnmode=2 and fnlock_default=1";

  eval-keyboard-backlight-binds = verdict "keyboard-backlight-binds" (
    hyprHasBind (binds default) "XF86KbdBrightnessUp" "brightness --keyboard up"
    && hyprHasBind (binds default) "XF86KbdBrightnessDown" "brightness --keyboard down"
    && hyprHasBind (binds default) "XF86KbdLightOnOff" "brightness --keyboard toggle"
    && hyprHasBind (binds default) "CTRL + XF86MonBrightnessUp" "brightness --keyboard up"
    && hyprHasBind (binds default) "CTRL + XF86MonBrightnessDown" "brightness --keyboard down"
  ) "keyboard backlight binds missing";

  eval-keyboard-backlight-disabled = verdict "keyboard-backlight-disabled" (
    !(hyprHasBind (binds noBacklight) "XF86KbdBrightnessUp" "brightness")
  ) "backlight.enable = false must drop the binds";

  eval-keyboard-shift-caps-options = verdict "keyboard-shift-caps-options" (
    lib.elem "marchyo:shift_caps_compose" (kbOptions shiftCaps)
    && !(lib.any (lib.hasPrefix "compose:") (kbOptions shiftCaps))
    && shiftCaps.config.environment.sessionVariables.XKB_CONFIG_EXTRA_PATH == "/etc/xkb"
    && shiftCaps.config.environment.etc ? xkb
    && !(lib.hasInfix "shift_caps" shiftCaps.config.services.xserver.xkb.options)
  ) "shift-caps should reach Hyprland only, with the extra path exported";

  eval-keyboard-menu-compose-unchanged = verdict "keyboard-menu-compose-unchanged" (
    lib.elem "compose:menu" (kbOptions menu) && !(menu.config.environment.etc ? xkb)
  ) "the menu compose key must stay on the stock option";

  # Hyprland only resolves the option with XKB_CONFIG_EXTRA_PATH set, so the
  # Hyprland env and uwsm's session env carry it too.
  eval-keyboard-shift-caps-session-env = verdict "keyboard-shift-caps-session-env" (
    hyprHasBind (hyprEnv default) "XKB_CONFIG_EXTRA_PATH" "/etc/xkb"
    && lib.hasInfix "XKB_CONFIG_EXTRA_PATH=/etc/xkb" (uwsmEnv default)
    && uwsmEnv menu == ""
  ) "XKB_CONFIG_EXTRA_PATH must reach the Hyprland and uwsm session env with shift-caps";

  eval-keyboard-compose-default-shift-caps = verdict "keyboard-compose-default-shift-caps" (
    lib.elem "marchyo:shift_caps_compose" (kbOptions default) && default.config.environment.etc ? xkb
  ) "the default compose key must be Shift+Caps Lock";

  # The custom <CAPS> symbols would land after ctrl:swapcaps and turn both
  # Caps Lock and Left Control into Caps Lock.
  eval-keyboard-caps-remap-keeps-menu-compose = verdict "keyboard-caps-remap-keeps-menu-compose" (
    swapCaps.config.marchyo.keyboard.composeKey == "menu"
    && lib.elem "compose:menu" (kbOptions swapCaps)
    && !(lib.elem "marchyo:shift_caps_compose" (kbOptions swapCaps))
  ) "a Caps Lock remap must fall back to the menu compose key";

  eval-keyboard-caps-remap-shift-caps-rejected = verdict "keyboard-caps-remap-shift-caps-rejected" (
    lib.any (a: !a.assertion) swapCapsShift.config.assertions
  ) "shift-caps with ctrl:swapcaps must fail an assertion";

  # libxkbcommon resolves the custom option against the generated tree: Caps
  # Lock keeps Caps_Lock on level 1 and Shift+Caps Lock yields Multi_key.
  eval-keyboard-shift-caps-xkbcli =
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
