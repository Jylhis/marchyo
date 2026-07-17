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
  # The toggle bind matches omarchy's Super+Ctrl+X (marchyo.dictation.toggleKey).
  hasToggleKeyBind =
    bindd: lib.any (b: lib.hasInfix "SUPER CTRL, X" b && lib.hasInfix "voxtype record toggle" b) bindd;
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
  # Dictation on: voxtype service enabled, the Super+Ctrl+X toggle bound, the
  # daemon push-to-talk hotkey (hold F9) configured, dictation user in the
  # `input` group, and the full UI layer present (waybar indicator, status-window
  # bind, notifications, audio).
  eval-dictation-enabled =
    let
      cfg = (evalWith { marchyo.dictation.enable = true; }).config;
      hm = cfg.home-manager.users.testuser;
      s = hm.services.voxtype.settings;
    in
    pkgs.writeText "eval-dictation-enabled" (
      if
        hm.services.voxtype.enable
        && hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bindd
        && hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bindd
        && hasStatusBind hm.wayland.windowManager.hyprland.settings.bindd
        && hasVoxtypeModule hm
        && s.output.notification.on_recording_start
        && s.audio.feedback.enabled
        && s.hotkey.enabled
        && s.hotkey.key == "F9"
        && s.hotkey.mode == "push_to_talk"
        && lib.elem "input" cfg.users.users.testuser.extraGroups
        && hm.services.voxtype.package.drvPath == pkgs.voxtype-vulkan.drvPath
      then
        "pass"
      else
        throw "FAIL: dictation enabled but a UI surface (bind, waybar module, notification, audio), the F9 push-to-talk hotkey, the input-group membership, or the GPU (Vulkan) voxtype build is missing/wrong"
    );

  # Push-to-talk opt-out: the daemon evdev hotkey is disabled and the user does
  # NOT gain the `input` group, but the Hyprland toggle bind stays.
  eval-dictation-pushtotalk-off =
    let
      cfg =
        (evalWith {
          marchyo.dictation.enable = true;
          marchyo.dictation.pushToTalk.enable = false;
        }).config;
      hm = cfg.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-pushtotalk-off" (
      if
        (!hm.services.voxtype.settings.hotkey.enabled)
        && (!lib.elem "input" cfg.users.users.testuser.extraGroups)
        && hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bindd
      then
        "pass"
      else
        throw "FAIL: pushToTalk.enable = false but the daemon hotkey is on, the user is in the input group, or the toggle bind is missing"
    );

  # GPU escape hatch: marchyo.dictation.gpu = false falls back to the CPU-only
  # voxtype build.
  eval-dictation-gpu-off =
    let
      hm =
        (evalWith {
          marchyo.dictation.enable = true;
          marchyo.dictation.gpu = false;
        }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-gpu-off" (
      if hm.services.voxtype.package.drvPath == pkgs.voxtype.drvPath then
        "pass"
      else
        throw "FAIL: dictation.gpu = false but the CPU-only voxtype build is not selected"
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
        throw "FAIL: dictation disabled but voxtype service, toggle bind or waybar module present"
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
