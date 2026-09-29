{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprEntriesText;

  # Resolve the rendered Hyprland `monitor` table list for a given
  # marchyo.monitors value (home hyprland reads it from osConfig).
  evalWith =
    monitors:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser {
          marchyo.desktop.enable = true;
          marchyo.monitors = monitors;
          home-manager.users.testuser = {
            imports = [ homeManagerModules ];
          };
        })
      ];
    };

  monitorText =
    monitors:
    hyprEntriesText (evalWith monitors)
      .config.home-manager.users.testuser.wayland.windowManager.hyprland.settings.monitor;

  assertText =
    name: monitors: needle:
    pkgs.writeText "eval-monitors-${name}" (
      let
        text = monitorText monitors;
      in
      if lib.hasInfix needle text then
        "pass"
      else
        throw "FAIL: monitors-${name}: expected '${needle}' in rendered monitor settings:\n${text}"
    );
in
{
  # Empty list (the default) keeps the historical catch-all rule.
  eval-monitors-default-catchall = assertText "default-catchall" [ ] "mode=preferred";

  # A declared output renders its name, mode, and position.
  eval-monitors-basic-output = assertText "basic-output" [
    {
      output = "DP-1";
      mode = "2560x1440@144";
      position = "0x0";
      scale = 1.0;
    }
  ] "output=DP-1";
  eval-monitors-basic-mode = assertText "basic-mode" [
    {
      output = "DP-1";
      mode = "2560x1440@144";
      position = "0x0";
      scale = 1.0;
    }
  ] "mode=2560x1440@144";

  # transform + vrr are emitted only when set (transform != 0, vrr != null).
  eval-monitors-transform = assertText "transform" [
    {
      output = "HDMI-A-1";
      transform = 1;
      vrr = 2;
    }
  ] "transform=1";

  # A disabled output renders Hyprland's `disabled = true` table field.
  eval-monitors-disabled = assertText "disabled" [
    {
      output = "eDP-1";
      enable = false;
    }
  ] "disabled=true";

  # extraSettings pass through verbatim.
  eval-monitors-extra = assertText "extra" [
    {
      output = "DP-2";
      extraSettings.bitdepth = 10;
    }
  ] "bitdepth=10";

  # Real Hyprland validation: a representative multi-output layout (with
  # transform, vrr, a disabled output, and an extraSettings key) must pass
  # `hyprland --verify-config` so a bad Lua monitor-table key is caught.
  check-monitors-hyprland-config =
    let
      eval = evalWith [
        {
          output = "eDP-1";
          mode = "2256x1504@60";
          position = "0x0";
          scale = 1.5;
        }
        {
          output = "DP-1";
          mode = "3840x2160@144";
          position = "auto-right";
          scale = 2.0;
          transform = 1;
          vrr = 1;
          extraSettings.bitdepth = 10;
        }
        {
          output = "HDMI-A-1";
          enable = false;
        }
      ];
      hyprlandConfig = eval.config.home-manager.users.testuser.xdg.configFile."hypr/hyprland.lua".source;
      hyprland = eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.package;
    in
    pkgs.runCommand "check-monitors-hyprland-config"
      {
        nativeBuildInputs = [ hyprland ];
      }
      ''
        export XDG_RUNTIME_DIR="$(mktemp -d)"
        log=$(mktemp)
        ${hyprland}/bin/hyprland --verify-config --config ${hyprlandConfig} 2>&1 | tee "$log"

        if ! grep -q -F 'config ok' "$log"; then
          echo "FAIL: hyprland --verify-config did not report 'config ok'" >&2
          exit 1
        fi
        if grep -E -i \
             -e 'config option <[^>]+> does not exist' \
             -e 'parse error' \
             -e 'attempt to (call|index) a nil value' \
             -e 'lua error' \
             "$log"; then
          echo "FAIL: hyprland --verify-config reported an error for the monitor layout" >&2
          exit 1
        fi
        touch "$out"
      '';
}
