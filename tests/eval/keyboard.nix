{ helpers, lib, ... }:
let
  inherit (helpers) testNixOS testNixOSCheck withTestUser;
in
{
  eval-keyboard = testNixOS "keyboard" (withTestUser {
    marchyo.keyboard = {
      layouts = [
        "us"
        {
          layout = "fi";
          variant = "";
        }
        {
          layout = "cn";
          ime = "pinyin";
          label = "中文";
        }
        {
          layout = "jp";
          ime = "mozc";
        }
      ];
      autoActivateIME = true;
      imeTriggerKey = [
        "Super+I"
        "Alt+grave"
      ];
      composeKey = "caps";
    };
  });

  eval-keyboard-no-compose = testNixOS "keyboard-no-compose" (withTestUser {
    marchyo.keyboard.composeKey = null;
  });

  # Pins the new defaults (us(altgr-intl) + fi, compose on Menu) so a
  # regression that re-introduces ralt-as-compose while keeping the
  # altgr-intl variant would be caught.
  eval-keyboard-default-altgr-intl = testNixOSCheck "keyboard-default-altgr-intl" (
    c:
    let
      xkb = c.services.xserver.xkb;
    in
    xkb.layout == "us,fi"
    && xkb.variant == "altgr-intl,"
    && lib.hasInfix "compose:menu" xkb.options
    && !(lib.hasInfix "compose:ralt" xkb.options)
  ) (withTestUser { });

  # Opt back into plain us with Right Alt as compose.
  eval-keyboard-plain-us-ralt = testNixOS "keyboard-plain-us-ralt" (withTestUser {
    marchyo.keyboard = {
      layouts = [ "us" ];
      composeKey = "ralt";
    };
  });

  # Deprecated marchyo.keyboard.variant still wins on the first layout even
  # when the default first layout ships with its own variant: the rendered
  # XKB variant string must start with "intl", overriding altgr-intl.
  eval-keyboard-legacy-variant =
    testNixOSCheck "keyboard-legacy-variant" (c: c.services.xserver.xkb.variant == "intl,")
      (withTestUser {
        marchyo.keyboard.variant = "intl";
      });
}
