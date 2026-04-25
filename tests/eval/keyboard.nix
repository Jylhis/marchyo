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
}
