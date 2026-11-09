# marchyo.shell.settings schema: typed keys render to shell.json, unset typed
# keys stay out of it, per-monitor overrides render under `monitors`, unknown
# keys pass through.
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

  hmWith =
    extra:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            marchyo.shell.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    }).config.home-manager.users.testuser;

  shellJsonOf = hm: builtins.fromJSON hm.xdg.configFile."marchyo/shell.json".text;

  check =
    name: cond: msg:
    pkgs.writeText name (if cond then "pass" else throw "FAIL: ${msg}");
in
{
  # Typed keys render with their values; unset typed keys are left out.
  eval-shell-settings-typed =
    let
      json = shellJsonOf (hmWith {
        marchyo.shell.settings = {
          bar.layout.left = [ { id = "marchyo.clock"; } ];
          idle.lock = 600;
          caffeine.autoVideo = false;
          clock.seconds = true;
          battery.percentage = false;
        };
      });
    in
    check "eval-shell-settings-typed" (
      json == {
        bar.layout.left = [ { id = "marchyo.clock"; } ];
        idle.lock = 600;
        caffeine.autoVideo = false;
        clock.seconds = true;
        battery.percentage = false;
      }
    ) "typed shell settings did not render exactly to shell.json: ${builtins.toJSON json}";

  # Per-monitor overrides render under `monitors.<output>`, entry settings
  # included, beside the global layout.
  eval-shell-settings-monitors =
    let
      json = shellJsonOf (hmWith {
        marchyo.shell.settings = {
          bar.layout.right = [ { id = "marchyo.battery"; } ];
          monitors."HDMI-A-1".bar.layout.right = [
            {
              id = "marchyo.clock";
              settings.format = "HH:mm";
            }
          ];
        };
      });
    in
    check "eval-shell-settings-monitors" (
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
    let
      json = shellJsonOf (hmWith {
        marchyo.shell.settings = {
          futureKey.nested = [ 1 ];
          bar.position = "top";
          bar.layout.left = [
            {
              id = "acme.weather";
              extra = true;
            }
          ];
          idle.dim = 60;
          monitors."DP-1".launcher.scale = 2;
        };
      });
    in
    check "eval-shell-settings-freeform" (
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

  # bar.style renders globally and per monitor, beside an untouched layout.
  eval-shell-settings-bar-style =
    let
      json = shellJsonOf (hmWith {
        marchyo.shell.settings = {
          bar.style = "segmented";
          monitors."HDMI-A-1".bar.style = "flat";
        };
      });
    in
    check "eval-shell-settings-bar-style" (
      json == {
        bar.style = "segmented";
        monitors."HDMI-A-1".bar.style = "flat";
      }
    ) "bar.style did not render to shell.json: ${builtins.toJSON json}";

  # The centre group renders as three sections beside left and right.
  eval-shell-settings-center-sections =
    let
      json = shellJsonOf (hmWith {
        marchyo.shell.settings.bar.layout = {
          centerBegin = [ { id = "marchyo.media"; } ];
          center = [ { id = "marchyo.clock"; } ];
          centerEnd = [ { id = "marchyo.dnd"; } ];
        };
      });
    in
    check "eval-shell-settings-center-sections" (
      json.bar.layout == {
        centerBegin = [ { id = "marchyo.media"; } ];
        center = [ { id = "marchyo.clock"; } ];
        centerEnd = [ { id = "marchyo.dnd"; } ];
      }
    ) "centerBegin/center/centerEnd did not render to shell.json: ${builtins.toJSON json}";

  # bar.style is a closed enum: an unknown look is rejected at eval.
  eval-shell-settings-bar-style-checked =
    let
      bad = builtins.tryEval (
        builtins.deepSeq (shellJsonOf (hmWith {
          marchyo.shell.settings.bar.style = "powerline";
        })) true
      );
    in
    check "eval-shell-settings-bar-style-checked" (
      !bad.success
    ) "bar.style accepted \"powerline\"; the enum is not enforced";

  # Nothing set: no shell.json, so the shell keeps its defaults.
  eval-shell-settings-empty-no-file =
    let
      hm = hmWith { };
    in
    check "eval-shell-settings-empty-no-file" (
      !(hm.xdg.configFile ? "marchyo/shell.json")
    ) "shell.json was written although marchyo.shell.settings is unset";

  # Typed leaves reject ill-typed values instead of rendering them.
  eval-shell-settings-type-checked =
    let
      bad = builtins.tryEval (
        builtins.deepSeq (shellJsonOf (hmWith {
          marchyo.shell.settings.idle.lock = "soon";
        })) true
      );
    in
    check "eval-shell-settings-type-checked" (
      !bad.success
    ) "idle.lock accepted a string; the typed option is not enforced";

  # marchyo.shell.diskWarnPercent reaches the shell as health.diskWarnPercent,
  # merged with the user's settings, and stays out of shell.json at its default.
  eval-shell-settings-disk-warn =
    let
      json = shellJsonOf (hmWith {
        marchyo.shell.diskWarnPercent = 20;
        marchyo.shell.settings.idle.lock = 600;
      });
    in
    check "eval-shell-settings-disk-warn" (
      json == {
        idle.lock = 600;
        health.diskWarnPercent = 20;
      }
    ) "diskWarnPercent did not render as health.diskWarnPercent: ${builtins.toJSON json}";

  eval-shell-settings-disk-warn-range =
    let
      bad = builtins.tryEval (
        builtins.deepSeq (shellJsonOf (hmWith {
          marchyo.shell.diskWarnPercent = 100;
        })) true
      );
    in
    check "eval-shell-settings-disk-warn-range" (
      !bad.success
    ) "diskWarnPercent accepted 100; the range is not enforced";
}
