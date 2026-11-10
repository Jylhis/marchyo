# marchyo.dictation.backend (voxtype): the default backend, its user service
# and input group, the Super+Ctrl+X toggle and the backend hint `marchyo
# dictation` reads. desktop-tweaks turns pushToTalk off (tests/eval/dictation.nix);
# desktop-tweaks-2 sets toggleKey = null.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind;

  hmOf = c: c.home-manager.users.testuser;
  binds = c: (hmOf c).wayland.windowManager.hyprland.settings.bind;
  failed = c: lib.filter (a: !a.assertion) c.assertions;
  hasHold = c: hyprHasBind (binds c) "F9" "dictation start";
  hasToggle = c: hyprHasBind (binds c) "SUPER + CTRL + X" "dictation toggle";
  clientConfig = c: (hmOf c).xdg.configFile."marchyo/dictation.json".text;
in
{
  refs = {
    desktop-dictation = {
      # The default backend is voxtype: its daemon keeps the F9 hotkey itself (no
      # Hyprland hold binds), users join `input` for it, and Super+Ctrl+X toggles
      # through the verb.
      eval-dictation-backend-default-voxtype =
        c:
        if
          c.marchyo.dictation.backend == "voxtype"
          && failed c == [ ]
          && (hmOf c).services.voxtype.enable
          && (builtins.fromJSON (clientConfig c)).backend == "voxtype"
          && hasToggle c
          && !(hasHold c)
          && lib.elem "input" c.users.users.testuser.extraGroups
        then
          true
        else
          "the default voxtype backend wiring is wrong (service, input group, no hold binds, toggle bind)";
    };

    desktop-tweaks = {
      # Without the daemon hotkey there is no reason to read /dev/input.
      eval-dictation-backend-no-push-to-talk-no-input =
        c:
        let
          off = c;
        in
        if !(lib.elem "input" off.users.users.testuser.extraGroups) && hasToggle off then
          true
        else
          "pushToTalk.enable = false should drop the input group and keep the toggle bind";
    };

    desktop = {
      # Dictation off: no voxtype unit, client config or bind.
      eval-dictation-backend-disabled =
        c:
        let
          off = c;
        in
        if
          failed off == [ ]
          && !(hmOf off).services.voxtype.enable
          && !(hasToggle off)
          && !(hmOf off).xdg.configFile ? "marchyo/dictation.json"
        then
          true
        else
          "dictation disabled but a backend unit, client config or bind is present";
    };

    desktop-tweaks-2 = {
      # toggleKey = null removes the Super+Ctrl+X bind.
      eval-dictation-backend-toggle-key-null =
        c:
        let
          none = c;
        in
        if !(hasToggle none) then true else "toggleKey = null left the toggle bind";
    };
  };

  refConfig.desktop-tweaks-2.marchyo.dictation = {
    enable = true;
    toggleKey = null;
  };
}
