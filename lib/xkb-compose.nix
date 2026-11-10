# XKB option for composeKey = "shift-caps": Caps Lock stays Caps Lock and
# Shift+Caps Lock is Compose. xkeyboard-config has no such option, so marchyo
# ships a symbols file and an evdev rules extension, found through
# XKB_CONFIG_EXTRA_PATH (libxkbcommon >= 1.0).
rec {
  customOption = "marchyo:shift_caps_compose";

  # Any option naming caps (ctrl:swapcaps, ctrl:nocaps, caps:escape,
  # grp:caps_toggle, ...) rebinds <CAPS>, which the custom symbols would
  # override, so Shift+Caps compose cannot coexist with it.
  remapsCaps = builtins.any (o: builtins.match ".*caps.*" o != null);

  # XKB option string for a composeKey value, or null for none.
  optionFor =
    key:
    if key == null then
      null
    else if key == "shift-caps" then
      customOption
    else
      "compose:${key}";

  tree =
    pkgs:
    pkgs.runCommand "marchyo-xkb" { } ''
      mkdir -p $out/symbols $out/rules
      cat > $out/symbols/marchyo <<'XKB'
      // Caps Lock stays Caps Lock; Shift + Caps Lock is Compose. The explicit
      // actions keep the Shift level from inheriting the Lock modifier.
      partial modifier_keys
      xkb_symbols "shift_caps_compose" {
        key <CAPS> {
          type[Group1] = "TWO_LEVEL",
          symbols[Group1] = [ Caps_Lock, Multi_key ],
          actions[Group1] = [ LockMods(modifiers = Lock), NoAction() ]
        };
      };
      XKB
      cat > $out/rules/evdev <<'XKB'
      ! include %S/evdev

      ! option = symbols
        marchyo:shift_caps_compose = +marchyo(shift_caps_compose)
      XKB
    '';
}
