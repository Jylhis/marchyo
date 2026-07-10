{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  hasVoxtypeBind = bindd: lib.any (b: lib.hasInfix "voxtype record toggle" b) bindd;
  hasStatusBind = bindd: lib.any (b: lib.hasInfix "voxtype status --follow" b) bindd;
  hasVoxtypeModule =
    hm: lib.elem "custom/voxtype" (builtins.elemAt hm.programs.waybar.settings 0).modules-right;

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
in
{
  # Dictation on: voxtype service enabled, Super+H toggle bound, and the full UI
  # layer present (waybar indicator, status-window bind, notifications, audio).
  eval-dictation-enabled =
    let
      hm = (evalWith { marchyo.dictation.enable = true; }).config.home-manager.users.testuser;
      s = hm.services.voxtype.settings;
    in
    pkgs.writeText "eval-dictation-enabled" (
      if
        hm.services.voxtype.enable
        && hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bindd
        && hasStatusBind hm.wayland.windowManager.hyprland.settings.bindd
        && hasVoxtypeModule hm
        && s.output.notification.on_recording_start
        && s.audio.feedback.enabled
      then
        "pass"
      else
        throw "FAIL: dictation enabled but a UI surface (bind, waybar module, notification or audio) is missing"
    );

  # Dictation off (default) on a desktop: no voxtype service, no dictation bind,
  # no waybar indicator.
  eval-dictation-disabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-disabled" (
      if
        (!hm.services.voxtype.enable)
        && (!hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bindd)
        && (!hasVoxtypeModule hm)
      then
        "pass"
      else
        throw "FAIL: dictation disabled but voxtype service, Super+H bind or waybar module present"
    );

  # Indicator opt-out: dictation stays enabled but the waybar segment drops out.
  eval-dictation-indicator-off =
    let
      hm =
        (evalWith {
          marchyo.dictation.enable = true;
          marchyo.dictation.indicator = false;
        }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-indicator-off" (
      if hm.services.voxtype.enable && (!hasVoxtypeModule hm) then
        "pass"
      else
        throw "FAIL: indicator disabled but custom/voxtype still on the bar (or service off)"
    );
}
