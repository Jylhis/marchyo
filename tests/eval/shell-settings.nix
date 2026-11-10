# marchyo.shell.settings schema: typed keys render to shell.json, unset typed
# keys stay out of it, per-monitor overrides render under `monitors`, unknown
# keys pass through.
#
# Two settings sets share the reference systems: desktop-tweaks carries the
# typed keys, bar.style and diskWarnPercent (its shell.json is compared
# exactly, so no unset key may leak in), desktop-tweaks-3 the per-monitor,
# freeform and centre-section keys. The type checks need no system at all:
# they evaluate the option declarations alone (helpers.evalOptions).
{ helpers, ... }:
let
  inherit (helpers) expect throws evalOptions;

  shellJsonOf =
    c: builtins.fromJSON c.home-manager.users.testuser.xdg.configFile."marchyo/shell.json".text;

  # Forcing the typed settings / diskWarnPercent against the declarations.
  rejects =
    module:
    let
      shell = (evalOptions module).marchyo.shell;
    in
    throws [
      shell.settings
      shell.diskWarnPercent
    ];
in
{
  refs = {
    desktop-tweaks = {
      # Typed keys render with their values; unset typed keys are left out
      # (the whole file is exactly what desktop-tweaks set).
      eval-shell-settings-typed =
        c:
        let
          json = shellJsonOf c;
        in
        expect (
          json == {
            bar.layout.left = [ { id = "marchyo.clock"; } ];
            bar.style = "segmented";
            monitors."HDMI-A-1".bar.style = "flat";
            idle.lock = 600;
            caffeine.autoVideo = false;
            clock.seconds = true;
            battery.percentage = false;
            health.diskWarnPercent = 20;
          }
        ) "typed shell settings did not render exactly to shell.json: ${builtins.toJSON json}";

      # bar.style renders globally and per monitor.
      eval-shell-settings-bar-style =
        c:
        let
          json = shellJsonOf c;
        in
        expect (
          json.bar.style == "segmented" && json.monitors."HDMI-A-1" == { bar.style = "flat"; }
        ) "bar.style did not render to shell.json: ${builtins.toJSON json}";

      # marchyo.shell.diskWarnPercent reaches the shell as health.diskWarnPercent,
      # merged with the user's settings (and, per eval-shell-settings-empty-no-file,
      # stays out of shell.json at its default).
      eval-shell-settings-disk-warn =
        c:
        let
          json = shellJsonOf c;
        in
        expect (
          json.health == { diskWarnPercent = 20; } && json.idle == { lock = 600; }
        ) "diskWarnPercent did not render as health.diskWarnPercent: ${builtins.toJSON json}";
    };

    desktop-tweaks-3 = {
      # Per-monitor overrides render under `monitors.<output>`, entry settings
      # included, beside the global layout.
      eval-shell-settings-monitors =
        c:
        let
          json = shellJsonOf c;
        in
        expect (
          json.bar.layout.right == [ { id = "marchyo.battery"; } ]
          &&
            json.monitors."HDMI-A-1" == {
              bar.layout.right = [
                {
                  id = "marchyo.clock";
                  settings.format = "HH:mm";
                }
              ];
            }
        ) "per-monitor override did not render under monitors.HDMI-A-1: ${builtins.toJSON json}";

      # Keys the schema does not name pass through at every level.
      eval-shell-settings-freeform =
        c:
        let
          json = shellJsonOf c;
        in
        expect (
          json.futureKey.nested == [ 1 ]
          && json.bar.position == "top"
          &&
            json.bar.layout.left == [
              {
                id = "acme.weather";
                extra = true;
              }
            ]
          && json.idle == { dim = 60; }
          && json.monitors."DP-1" == { launcher.scale = 2; }
        ) "unknown shell settings keys did not pass through: ${builtins.toJSON json}";

      # The centre group renders as three sections beside left and right.
      eval-shell-settings-center-sections =
        c:
        let
          inherit ((shellJsonOf c).bar) layout;
        in
        expect (
          layout.centerBegin == [ { id = "marchyo.media"; } ]
          && layout.center == [ { id = "marchyo.clock"; } ]
          && layout.centerEnd == [ { id = "marchyo.dnd"; } ]
        ) "centerBegin/center/centerEnd did not render to shell.json: ${builtins.toJSON layout}";
    };

    # Nothing set: no shell.json, so the shell keeps its defaults.
    desktop.eval-shell-settings-empty-no-file =
      c:
      expect (
        !(c.home-manager.users.testuser.xdg.configFile ? "marchyo/shell.json")
      ) "shell.json was written although marchyo.shell.settings is unset";
  };

  refConfig = {
    desktop-tweaks.marchyo.shell = {
      diskWarnPercent = 20;
      settings = {
        bar.layout.left = [ { id = "marchyo.clock"; } ];
        bar.style = "segmented";
        monitors."HDMI-A-1".bar.style = "flat";
        idle.lock = 600;
        caffeine.autoVideo = false;
        clock.seconds = true;
        battery.percentage = false;
      };
    };
    desktop-tweaks-3.marchyo.shell.settings = {
      futureKey.nested = [ 1 ];
      bar.position = "top";
      bar.layout = {
        left = [
          {
            id = "acme.weather";
            extra = true;
          }
        ];
        right = [ { id = "marchyo.battery"; } ];
        centerBegin = [ { id = "marchyo.media"; } ];
        center = [ { id = "marchyo.clock"; } ];
        centerEnd = [ { id = "marchyo.dnd"; } ];
      };
      idle.dim = 60;
      monitors = {
        "DP-1".launcher.scale = 2;
        "HDMI-A-1".bar.layout.right = [
          {
            id = "marchyo.clock";
            settings.format = "HH:mm";
          }
        ];
      };
    };
  };

  checks = {
    # bar.style is a closed enum: an unknown look is rejected at eval.
    eval-shell-settings-bar-style-checked = helpers.assertTest "shell-settings-bar-style-checked" (
      rejects { marchyo.shell.settings.bar.style = "powerline"; }
      && !(rejects { marchyo.shell.settings.bar.style = "segmented"; })
    ) "bar.style accepted \"powerline\"; the enum is not enforced";

    # Typed leaves reject ill-typed values instead of rendering them.
    eval-shell-settings-type-checked = helpers.assertTest "shell-settings-type-checked" (
      rejects { marchyo.shell.settings.idle.lock = "soon"; }
      && !(rejects { marchyo.shell.settings.idle.lock = 600; })
    ) "idle.lock accepted a string; the typed option is not enforced";

    eval-shell-settings-disk-warn-range = helpers.assertTest "shell-settings-disk-warn-range" (
      rejects { marchyo.shell.diskWarnPercent = 100; }
      && !(rejects { marchyo.shell.diskWarnPercent = 20; })
    ) "diskWarnPercent accepted 100; the range is not enforced";
  };
}
