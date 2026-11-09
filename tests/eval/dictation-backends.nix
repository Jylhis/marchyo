# Evaluation tests for marchyo.dictation.backend (voxtype): the default
# backend, its user service and input group, the Alt+Space toggle and the
# backend hint `marchyo dictation` reads.
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
            marchyo.dictation.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  hmOf = eval: eval.config.home-manager.users.testuser;
  binds = eval: (hmOf eval).wayland.windowManager.hyprland.settings.bind;
  failed = eval: lib.filter (a: !a.assertion) eval.config.assertions;
  hasHold = eval: hyprHasBind (binds eval) "F9" "dictation start";
  hasToggle = eval: hyprHasBind (binds eval) "ALT + SPACE" "dictation toggle";
  clientConfig = eval: (hmOf eval).xdg.configFile."marchyo/dictation.json".text;

  default = evalWith { };
in
{
  # The default backend is voxtype: its daemon keeps the F9 hotkey itself (no
  # Hyprland hold binds), users join `input` for it, and Alt+Space toggles
  # through the verb.
  eval-dictation-backend-default-voxtype = pkgs.writeText "eval-dictation-backend-default-voxtype" (
    if
      default.config.marchyo.dictation.backend == "voxtype"
      && failed default == [ ]
      && (hmOf default).services.voxtype.enable
      && (builtins.fromJSON (clientConfig default)).backend == "voxtype"
      && hasToggle default
      && !(hasHold default)
      && lib.elem "input" default.config.users.users.testuser.extraGroups
    then
      "pass"
    else
      throw "FAIL: the default voxtype backend wiring is wrong (service, input group, no hold binds, toggle bind)"
  );

  # Without the daemon hotkey there is no reason to read /dev/input.
  eval-dictation-backend-no-push-to-talk-no-input =
    let
      off = evalWith { marchyo.dictation.pushToTalk.enable = false; };
    in
    pkgs.writeText "eval-dictation-backend-no-push-to-talk-no-input" (
      if !(lib.elem "input" off.config.users.users.testuser.extraGroups) && hasToggle off then
        "pass"
      else
        throw "FAIL: pushToTalk.enable = false should drop the input group and keep the toggle bind"
    );

  # Dictation off: no voxtype unit, client config or bind.
  eval-dictation-backend-disabled =
    let
      off = evalWith { marchyo.dictation.enable = false; };
    in
    pkgs.writeText "eval-dictation-backend-disabled" (
      if
        failed off == [ ]
        && !(hmOf off).services.voxtype.enable
        && !(hasToggle off)
        && !(hmOf off).xdg.configFile ? "marchyo/dictation.json"
      then
        "pass"
      else
        throw "FAIL: dictation disabled but a backend unit, client config or bind is present"
    );

  # toggleKey = null removes the Alt+Space bind.
  eval-dictation-backend-toggle-key-null =
    let
      none = evalWith { marchyo.dictation.toggleKey = null; };
    in
    pkgs.writeText "eval-dictation-backend-toggle-key-null" (
      if !(hasToggle none) then "pass" else throw "FAIL: toggleKey = null left the toggle bind"
    );
}
