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

  hasStatusBind = binds: lib.hasInfix "voxtype status --follow" (hyprEntriesText binds);
  # Alt+Space toggles through the backend-neutral verb (marchyo.dictation.toggleKey).
  hasToggleKeyBind = binds: hyprHasBind binds "ALT + SPACE" "dictation toggle";
  hasHoldBinds =
    binds:
    hyprHasBind binds "F9" "dictation start"
    && hyprHasBind binds "F9" "dictation stop"
    && lib.hasInfix "release=true" (hyprEntriesText binds);
  # The shell bakes the dictation indicator into its package, so the flag shows
  # up as a different shell store path.
  shellExec = hm: toString hm.systemd.user.services.marchyo-shell.Service.ExecStart;

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
  voxtypeEval =
    extra: evalWith (lib.recursiveUpdate { marchyo.dictation.backend = "voxtype"; } extra);
in
{
  # Dictation on: voxtype service enabled, the Alt+Space toggle bound, the
  # daemon push-to-talk hotkey (hold F9) configured, dictation user in the
  # `input` group, and the full UI layer present (status-window bind,
  # notifications, audio).
  eval-dictation-enabled =
    let
      cfg = (voxtypeEval { marchyo.dictation.enable = true; }).config;
      hm = cfg.home-manager.users.testuser;
      s = hm.services.voxtype.settings;
    in
    pkgs.writeText "eval-dictation-enabled" (
      if
        hm.services.voxtype.enable
        && !hasHoldBinds hm.wayland.windowManager.hyprland.settings.bind
        && hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bind
        && hasStatusBind hm.wayland.windowManager.hyprland.settings.bind
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
        throw "FAIL: dictation enabled but a UI surface (bind, notification, audio), the F9 push-to-talk hotkey, the input-group membership, or the GPU (Vulkan) voxtype build is missing/wrong"
    );

  # Push-to-talk opt-out: the daemon evdev hotkey is disabled and the user does
  # NOT gain the `input` group, but the Hyprland toggle bind stays.
  eval-dictation-pushtotalk-off =
    let
      cfg =
        (voxtypeEval {
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
        (voxtypeEval {
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

  # Dictation off (default) on a desktop: no voxtype service, no dictation bind.
  eval-dictation-disabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-disabled" (
      if
        (!hm.services.voxtype.enable) && (!hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bind)
      then
        "pass"
      else
        throw "FAIL: dictation disabled but voxtype service or toggle bind present"
    );

  # Depth options: on-demand model loading + GPU isolation reach whisper
  # settings, and the replacements / spoken-punctuation table reaches text.
  eval-dictation-depth-settings =
    let
      s =
        (voxtypeEval {
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
        (voxtypeEval { marchyo.dictation.enable = true; })
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
        (voxtypeEval { marchyo.dictation.enable = true; })
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
        (voxtypeEval {
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

  # Indicator opt-out: dictation stays enabled but the shell is built without
  # the bar indicator, the same shell as with dictation off.
  eval-dictation-indicator-off =
    let
      hmFor = extra: (voxtypeEval extra).config.home-manager.users.testuser;
      off = hmFor {
        marchyo.dictation.enable = true;
        marchyo.dictation.indicator = false;
      };
      on = hmFor { marchyo.dictation.enable = true; };
      disabled = hmFor { };
    in
    pkgs.writeText "eval-dictation-indicator-off" (
      if !off.services.voxtype.enable then
        throw "FAIL: indicator disabled but the voxtype service is off"
      else if shellExec off != shellExec disabled then
        throw "FAIL: indicator disabled but the shell still bakes the dictation indicator"
      else if shellExec on == shellExec disabled then
        throw "FAIL: dictation enabled but the shell does not bake the dictation indicator"
      else
        "pass"
    );
}
