# Dictation (voxtype): the default wiring on desktop-dictation (the desktop with
# marchyo.dictation.enable and nothing else), the opt-outs and depth options on
# desktop-tweaks, and the indicator opt-out on its own variant: that test
# compares shell builds, so its configuration may differ from
# desktop-dictation in nothing but the indicator (and silenceGate, which the
# shell build does not read).
{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) hyprHasBind hyprEntriesText;

  hasStatusBind = binds: lib.hasInfix "voxtype status --follow" (hyprEntriesText binds);
  # Super+Ctrl+X toggles through the backend-neutral verb (marchyo.dictation.toggleKey).
  hasToggleKeyBind = binds: hyprHasBind binds "SUPER + CTRL + X" "dictation toggle";
  hasHoldBinds =
    binds:
    hyprHasBind binds "F9" "dictation start"
    && hyprHasBind binds "F9" "dictation stop"
    && lib.hasInfix "release=true" (hyprEntriesText binds);
  # The shell bakes the dictation indicator into its package, so the flag shows
  # up as a different shell store path.
  shellExec = hm: toString hm.systemd.user.services.marchyo-shell.Service.ExecStart;

in
{
  refs = {
    desktop-dictation = {
      # Dictation on: voxtype service enabled, the Super+Ctrl+X toggle bound, the
      # daemon push-to-talk hotkey (hold F9) configured, dictation user in the
      # `input` group, and the full UI layer present (status-window bind,
      # notifications, audio).
      eval-dictation-enabled =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          s = hm.services.voxtype.settings;
        in
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
          true
        else
          "dictation enabled but a UI surface (bind, notification, audio), the F9 push-to-talk hotkey, the input-group membership, or the GPU (Vulkan) voxtype build is missing/wrong";

      # Default: no text block is emitted (replacements empty, spoken punctuation
      # off), so the upstream default config is left untouched.
      eval-dictation-no-text-by-default =
        c:
        let
          s = c.home-manager.users.testuser.services.voxtype.settings;
        in
        if (!(s ? text)) && (!s.whisper.on_demand_loading) then
          true
        else
          "dictation defaults emit a text block or on-demand loading unexpectedly";

      # Silence gate on by default: voxtype's [vad] section is enabled with the
      # model-free energy backend, so a silent recording is dropped before Whisper.
      eval-dictation-silence-gate-default =
        c:
        let
          s = c.home-manager.users.testuser.services.voxtype.settings;
        in
        if
          s.vad.enabled
          && s.vad.backend == "energy"
          && s.vad.threshold == 0.5
          && s.vad.min_speech_duration_ms == 100
        then
          true
        else
          "dictation enabled but the [vad] silence gate is off or not on energy/0.5/100ms defaults";
    };

    desktop-tweaks = {
      # Push-to-talk opt-out: the daemon evdev hotkey is disabled and the user does
      # NOT gain the `input` group, but the Hyprland toggle bind stays.
      eval-dictation-pushtotalk-off =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
        in
        if
          (!hm.services.voxtype.settings.hotkey.enabled)
          && (!lib.elem "input" cfg.users.users.testuser.extraGroups)
          && hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bind
        then
          true
        else
          "pushToTalk.enable = false but the daemon hotkey is on, the user is in the input group, or the toggle bind is missing";

      # GPU escape hatch: marchyo.dictation.gpu = false falls back to the CPU-only
      # voxtype build.
      eval-dictation-gpu-off =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if hm.services.voxtype.package.drvPath == pkgs.voxtype.drvPath then
          true
        else
          "dictation.gpu = false but the CPU-only voxtype build is not selected";

      # Depth options: on-demand model loading + GPU isolation reach whisper
      # settings, and the replacements / spoken-punctuation table reaches text.
      eval-dictation-depth-settings =
        c:
        let
          s = c.home-manager.users.testuser.services.voxtype.settings;
        in
        if
          s.whisper.on_demand_loading
          && s.whisper.gpu_isolation
          && s.text.spoken_punctuation
          && (s.text.replacements."vox type" == "voxtype")
        then
          true
        else
          "dictation depth options did not reach voxtype settings (whisper.on_demand_loading/gpu_isolation, text.spoken_punctuation/replacements)";

      # Silence gate overrides reach [vad], and enable = false turns detection off.
      eval-dictation-silence-gate-settings =
        c:
        let
          tuned = c.home-manager.users.testuser.services.voxtype.settings;
        in
        if
          tuned.vad.enabled
          && tuned.vad.backend == "whisper"
          && tuned.vad.threshold == 0.7
          && tuned.vad.min_speech_duration_ms == 250
        then
          true
        else
          "silenceGate backend/threshold/minSpeechMs did not reach voxtype [vad]";
    };

    desktop = {
      # Dictation off (default) on a desktop: no voxtype service, no dictation bind.
      eval-dictation-disabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          (!hm.services.voxtype.enable) && (!hasToggleKeyBind hm.wayland.windowManager.hyprland.settings.bind)
        then
          true
        else
          "dictation disabled but voxtype service or toggle bind present";
    };

  };

  refConfig.desktop-tweaks.marchyo.dictation = {
    enable = true;
    pushToTalk.enable = false;
    gpu = false;
    onDemandModel = true;
    gpuIsolation = true;
    spokenPunctuation = true;
    replacements = {
      "vox type" = "voxtype";
    };
    silenceGate = {
      backend = "whisper";
      threshold = 0.7;
      minSpeechMs = 250;
    };
  };

  variants.dictation-indicator-off = {
    config = helpers.desktopWith {
      marchyo.dictation = {
        enable = true;
        indicator = false;
        # Does not reach the shell build.
        silenceGate.enable = false;
      };
    };
    predicates = {
      # silenceGate.enable = false turns detection off.
      eval-dictation-silence-gate-settings-off =
        c: !c.home-manager.users.testuser.services.voxtype.settings.vad.enabled;

      # Indicator opt-out: dictation stays enabled but the shell is built without
      # the bar indicator, the same shell as with dictation off. The one test
      # that compares builds of other systems (two more evaluations, freed
      # with this check).
      eval-dictation-indicator-off =
        c:
        let
          hmFor = cfg: cfg.home-manager.users.testuser;
          off = hmFor c;
          on = hmFor (helpers.ref "desktop-dictation").config;
          disabled = hmFor (helpers.ref "desktop").config;
        in
        if !off.services.voxtype.enable then
          "indicator disabled but the voxtype service is off"
        else if shellExec off != shellExec disabled then
          "indicator disabled but the shell still bakes the dictation indicator"
        else if shellExec on == shellExec disabled then
          "dictation enabled but the shell does not bake the dictation indicator"
        else
          true;
    };
  };
}
