{ helpers, lib, ... }:
let
  inherit (helpers) testNixOS testNixOSCheck withTestUser;

  cjkLayouts = [
    "us"
    {
      layout = "jp";
      ime = "mozc";
    }
    {
      layout = "kr";
      ime = "hangul";
    }
    {
      layout = "cn";
      ime = "pinyin";
    }
    {
      layout = "us";
      ime = "chewing";
    }
    {
      layout = "us";
      ime = "cangjie";
    }
  ];

  cjkConfig = withTestUser {
    marchyo = {
      desktop.enable = true;
      keyboard.layouts = cjkLayouts;
    };
  };

  fcitx = cfg: cfg.i18n.inputMethod.fcitx5;
  profile = cfg: (fcitx cfg).settings.inputMethod;
  global = cfg: (fcitx cfg).settings.globalOptions;
  addonNames = cfg: map (p: p.pname or p.name) (fcitx cfg).addons;
  hasAddon = cfg: name: lib.any (n: lib.hasPrefix name n) (addonNames cfg);
  itemNames =
    cfg:
    map (i: i.Name) (
      lib.attrValues (lib.filterAttrs (n: _: lib.hasPrefix "Groups/0/Items/" n) (profile cfg))
    );
  localConf = cfg: cfg.fonts.fontconfig.localConf;
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

  # Pins the new defaults (us(altgr-intl) + fi, compose on Shift+Caps Lock) so a
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

  eval-keyboard-cjk-addons = testNixOSCheck "keyboard-cjk-addons" (
    cfg:
    hasAddon cfg "fcitx5-chewing"
    && hasAddon cfg "fcitx5-table-extra"
    && hasAddon cfg "fcitx5-mozc"
    && hasAddon cfg "fcitx5-hangul"
    && hasAddon cfg "fcitx5-chinese-addons"
  ) cjkConfig;

  eval-keyboard-cjk-profile = testNixOSCheck "keyboard-cjk-profile" (
    cfg:
    let
      names = itemNames cfg;
      keyboards = lib.filter (lib.hasPrefix "keyboard-") names;
    in
    # Layouts come first, engines after, and input starts on a keyboard item.
    names == keyboards
    ++ [
      "mozc"
      "hangul"
      "pinyin"
      "chewing"
      "cangjie"
    ]
    && (profile cfg)."Groups/0".DefaultIM == "keyboard-us"
    && (global cfg).Behavior.ActiveByDefault == false
    && (profile cfg)."Groups/0/Items/0".Name == "keyboard-us"
    && lib.elem "keyboard-kr-kr104" names
    && (profile cfg)."Groups/0/Items/${toString (lib.length keyboards + 1)}".Layout == "kr(kr104)"
  ) cjkConfig;

  eval-keyboard-cjk-hotkeys = testNixOSCheck "keyboard-cjk-hotkeys" (
    cfg:
    (global cfg)."Hotkey/AltTriggerKeys" == {
      "0" = "Shift_L";
      "1" = "Shift_R";
    }
    &&
      (global cfg)."Hotkey/TriggerKeys" == {
        "0" = "Super+Space";
        "1" = "Super+I";
      }
    && (global cfg).Hotkey.EnumerateWithTriggerKeys == true
  ) cjkConfig;

  eval-keyboard-cjk-fontconfig = testNixOSCheck "keyboard-cjk-fontconfig" (
    cfg:
    lib.all (s: lib.hasInfix s (localConf cfg)) [
      "<string>ja</string>"
      "<string>ko</string>"
      "<string>zh-cn</string>"
      "<string>zh-tw</string>"
      "<string>zh-hk</string>"
      "Noto Sans CJK JP"
      "Noto Serif CJK KR"
      "Noto Sans Mono CJK SC"
      "Noto Sans CJK TC"
      "Noto Serif CJK HK"
    ]
  ) cjkConfig;

  eval-keyboard-no-cjk-fontconfig =
    testNixOSCheck "keyboard-no-cjk-fontconfig" (cfg: !(lib.hasInfix "Noto Sans CJK" (localConf cfg)))
      (withTestUser {
        marchyo.desktop.enable = true;
      });
}
