# Keyboard layouts, compose key and the fcitx5 input-method profile.
# Each reference system's tweaks are in refConfig at the bottom.
{ lib, ... }:
let
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
  refs = {
    headless-tweaks-2.eval-keyboard =
      cfg: lib.length cfg.marchyo.keyboard.layouts == 4 && cfg.marchyo.keyboard.composeKey == "caps";

    headless-tweaks.eval-keyboard-no-compose = cfg: cfg.marchyo.keyboard.composeKey == null;

    # Pins the new defaults (us(altgr-intl) + fi, compose on the Menu key) so a
    # regression that re-introduces ralt-as-compose while keeping the
    # altgr-intl variant would be caught.
    headless.eval-keyboard-default-altgr-intl = cfg: cfg.marchyo.keyboard.composeKey == "menu";

    # Opt back into plain us with Right Alt as compose.
    headless-tweaks-3.eval-keyboard-plain-us-ralt =
      cfg: cfg.marchyo.keyboard.layouts == [ "us" ] && cfg.marchyo.keyboard.composeKey == "ralt";

    # Deprecated marchyo.keyboard.variant still wins on the first layout even
    # when the default first layout ships with its own variant.
    headless-tweaks-4.eval-keyboard-legacy-variant = cfg: cfg.marchyo.keyboard.variant == "intl";

    desktop-tweaks-2 = {
      eval-keyboard-cjk-addons =
        cfg:
        hasAddon cfg "fcitx5-chewing"
        && hasAddon cfg "fcitx5-table-extra"
        && hasAddon cfg "fcitx5-mozc"
        && hasAddon cfg "fcitx5-hangul"
        && hasAddon cfg "fcitx5-chinese-addons";

      eval-keyboard-cjk-profile =
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
        && (profile cfg)."Groups/0/Items/${toString (lib.length keyboards + 1)}".Layout == "kr(kr104)";

      eval-keyboard-cjk-hotkeys =
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
        && (global cfg).Hotkey.EnumerateWithTriggerKeys == true;

      eval-keyboard-cjk-fontconfig =
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
        ];
    };

    desktop.eval-keyboard-no-cjk-fontconfig = cfg: !(lib.hasInfix "Noto Sans CJK" (localConf cfg));
  };

  refConfig = {
    headless-tweaks.marchyo.keyboard.composeKey = null;
    headless-tweaks-2.marchyo.keyboard = {
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
    headless-tweaks-3.marchyo.keyboard = {
      layouts = [ "us" ];
      composeKey = "ralt";
    };
    headless-tweaks-4.marchyo.keyboard.variant = "intl";
    desktop-tweaks-2.marchyo.keyboard.layouts = cjkLayouts;
  };
}
