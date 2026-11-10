# Declarative monitors (marchyo.monitors) render to Hyprland's `monitor`
# tables, and the monitor panel's saved-settings loader runs after them.
# desktop-tweaks-4 declares one output per rendering feature (a plain mode
# and position, transform + vrr, a disabled output, extraSettings); the same
# layout seeds the per-monitor workspace blocks (tests/eval/workspaces.nix) and
# is what the heavy Hyprland checks verify.
{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) hyprEntriesText ref;

  hmOf = c: c.home-manager.users.testuser;
  luaOf = c: (hmOf c).xdg.configFile."hypr/hyprland.lua".text;
  monitorText = c: hyprEntriesText (hmOf c).wayland.windowManager.hyprland.settings.monitor;

  # `needle` appears in the rendered monitor settings.
  rendered =
    needle: c:
    let
      text = monitorText c;
    in
    helpers.expect (lib.hasInfix needle text) "expected '${needle}' in rendered monitor settings:\n${text}";

  expect = cond: msg: lib.optional (!cond) msg;

  indexOf =
    needle: text:
    let
      parts = lib.splitString needle text;
    in
    if builtins.length parts < 2 then -1 else builtins.stringLength (builtins.head parts);

  settingsLine = ''
    1		1920x1080@60	0x0	1.5	1		BOE 0x095F
    0						Dell U2720Q ABC
    	3840x2160@144	1920x0	2	0	internal	Acme Panel 42
  '';

  settingsDir = pkgs.writeTextDir "marchyo/monitors/settings" settingsLine;

  declared = hmOf (ref "desktop-tweaks-4").config;
  hyprland = declared.wayland.windowManager.hyprland.package;
  hyprlandConfig = declared.xdg.configFile."hypr/hyprland.lua".source;
in
{
  refs = {
    # Empty list (the default) keeps the historical catch-all rule.
    desktop.eval-monitors-default-catchall = rendered "mode=preferred";

    desktop-tweaks-4 = {
      # A declared output renders its name, mode, and position.
      eval-monitors-basic-output = rendered "output=DP-1";
      eval-monitors-basic-mode = rendered "mode=2560x1440@144";

      # transform + vrr are emitted only when set (transform != 0, vrr != null).
      eval-monitors-transform = rendered "transform=1";

      # A disabled output renders Hyprland's `disabled = true` table field.
      eval-monitors-disabled = rendered "disabled=true";

      # extraSettings pass through verbatim.
      eval-monitors-extra = rendered "bitdepth=10";

      # Default: the saved-settings loader runs after the declarative monitor rules.
      eval-monitor-panel-loader =
        c:
        let
          lua = luaOf c;
        in
        expect (lib.hasInfix "hyprland-monitor-settings.lua" lua) "loader is not loaded"
        ++ expect (
          indexOf "hyprland-monitor-settings.lua" lua > indexOf "hl.monitor(" lua
        ) "loader does not come after the declarative monitor rules";
    };

    # marchyo.monitorPanel.persist = false (desktop-off) leaves the file unread.
    desktop-off.eval-monitor-panel-off =
      c:
      let
        lua = luaOf c;
      in
      expect (!(lib.hasInfix "hyprland-monitor-settings.lua" lua)) "loader loaded with persist off"
      ++ expect (lib.hasInfix "hl.monitor(" lua) "declarative monitors lost";
  };

  refConfig = {
    desktop-tweaks-4.marchyo.monitors = [
      {
        output = "DP-2";
        position = "auto-right";
        scale = 2.0;
        extraSettings.bitdepth = 10;
      }
      {
        output = "HDMI-A-1";
        enable = false;
      }
      {
        output = "eDP-1";
        scale = 1.5;
        transform = 1;
        vrr = 2;
      }
      {
        output = "DP-1";
        mode = "2560x1440@144";
        position = "0x0";
        scale = 1.0;
      }
    ];
    desktop-off.marchyo.monitorPanel.persist = false;
  };

  heavy = {
    # Real Hyprland validation of the declared layout (transform, vrr, a
    # disabled output, an extraSettings key): a bad Lua monitor-table key is
    # caught.
    check-monitors-hyprland-config =
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

    # The loader runs under Hyprland's Lua with a settings file in place.
    check-monitor-panel-hyprland-config =
      pkgs.runCommand "check-monitor-panel-hyprland-config"
        {
          nativeBuildInputs = [ hyprland ];
        }
        ''
          export XDG_RUNTIME_DIR="$(mktemp -d)"
          export XDG_STATE_HOME=${settingsDir}
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
            echo "FAIL: hyprland --verify-config reported an error with saved display settings" >&2
            exit 1
          fi
          touch "$out"
        '';
  };
}
