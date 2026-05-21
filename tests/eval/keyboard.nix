{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
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
  eval-keyboard-default-altgr-intl = testNixOS "keyboard-default-altgr-intl" (withTestUser { });

  # Opt back into plain us with Right Alt as compose.
  eval-keyboard-plain-us-ralt = testNixOS "keyboard-plain-us-ralt" (withTestUser {
    marchyo.keyboard = {
      layouts = [ "us" ];
      composeKey = "ralt";
    };
  });

  # Deprecated marchyo.keyboard.variant still wins on the first layout even
  # when the default first layout ships with its own variant.
  eval-keyboard-legacy-variant = testNixOS "keyboard-legacy-variant" (withTestUser {
    marchyo.keyboard.variant = "intl";
  });
}
