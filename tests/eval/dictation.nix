{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntriesText;

  hasVoxtypeBind = binds: lib.hasInfix "voxtype record toggle" (hyprEntriesText binds);
  hasStatusBind = binds: lib.hasInfix "voxtype status --follow" (hyprEntriesText binds);
  # The toggle bind matches omarchy's Super+Ctrl+X (marchyo.dictation.toggleKey).
  hasToggleKeyBind = binds: hyprHasBind binds "SUPER + CTRL + X" "voxtype record toggle";
  hasVoxtypeModule =
    hm: lib.elem "custom/voxtype" (builtins.elemAt hm.programs.waybar.settings 0).modules-right;

  # The indicator assertions read the waybar segment, so these tests pin the
  # marchyo.shell.enable = false fallback; the shell bar draws its own.
  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            marchyo.shell.enable = false;
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
        && hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bind
        && hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bind
        && hasStatusBind hm.wayland.windowManager.hyprland.settings.bind
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
        && hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bind
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
        && (!hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bind)
        && (!hasVoxtypeModule hm)
      then
        "pass"
      else
        throw "FAIL: dictation disabled but voxtype service, toggle bind or waybar module present"
    );

  # Depth options: on-demand model loading + GPU isolation reach whisper
  # settings, and the replacements / spoken-punctuation table reaches text.
  eval-dictation-depth-settings =
    let
      s =
        (evalWith {
          marchyo.dictation.enable = true;
          marchyo.dictation.onDemandModel = true;
          marchyo.dictation.gpuIsolation = true;
          marchyo.dictation.spokenPunctuation = true;
          marchyo.dictation.replacements = {
            "vox type" = "voxtype";
          };
        }).config.home-manager.users.testuser.services.voxtype.settings;
    in
    pkgs.writeText "eval-dictation-depth-settings" (
      if
        s.whisper.on_demand_loading
        && s.whisper.gpu_isolation
        && s.text.spoken_punctuation
        && (s.text.replacements."vox type" == "voxtype")
      then
        "pass"
      else
        throw "FAIL: dictation depth options did not reach voxtype settings (whisper.on_demand_loading/gpu_isolation, text.spoken_punctuation/replacements)"
    );

  # Default: no text block is emitted (replacements empty, spoken punctuation
  # off), so the upstream default config is left untouched.
  eval-dictation-no-text-by-default =
    let
      s =
        (evalWith { marchyo.dictation.enable = true; })
        .config.home-manager.users.testuser.services.voxtype.settings;
    in
    pkgs.writeText "eval-dictation-no-text-by-default" (
      if (!(s ? text)) && (!s.whisper.on_demand_loading) then
        "pass"
      else
        throw "FAIL: dictation defaults emit a text block or on-demand loading unexpectedly"
    );

  # Silence gate on by default: voxtype's [vad] section is enabled with the
  # model-free energy backend, so a silent recording is dropped before Whisper.
  eval-dictation-silence-gate-default =
    let
      s =
        (evalWith { marchyo.dictation.enable = true; })
        .config.home-manager.users.testuser.services.voxtype.settings;
    in
    pkgs.writeText "eval-dictation-silence-gate-default" (
      if
        s.vad.enabled
        && s.vad.backend == "energy"
        && s.vad.threshold == 0.5
        && s.vad.min_speech_duration_ms == 100
      then
        "pass"
      else
        throw "FAIL: dictation enabled but the [vad] silence gate is off or not on energy/0.5/100ms defaults"
    );

  # Silence gate overrides reach [vad], and enable = false turns detection off.
  eval-dictation-silence-gate-settings =
    let
      settingsFor =
        gate:
        (evalWith {
          marchyo.dictation.enable = true;
          marchyo.dictation.silenceGate = gate;
        }).config.home-manager.users.testuser.services.voxtype.settings;
      tuned = settingsFor {
        backend = "whisper";
        threshold = 0.7;
        minSpeechMs = 250;
      };
      off = settingsFor { enable = false; };
    in
    pkgs.writeText "eval-dictation-silence-gate-settings" (
      if
        tuned.vad.enabled
        && tuned.vad.backend == "whisper"
        && tuned.vad.threshold == 0.7
        && tuned.vad.min_speech_duration_ms == 250
        && (!off.vad.enabled)
      then
        "pass"
      else
        throw "FAIL: silenceGate backend/threshold/minSpeechMs did not reach voxtype [vad], or enable = false left it on"
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
