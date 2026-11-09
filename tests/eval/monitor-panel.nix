{
  lib,
  pkgs,
  helpers,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

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

  hmOf = eval: eval.config.home-manager.users.testuser;
  luaOf = eval: (hmOf eval).xdg.configFile."hypr/hyprland.lua".text;

  check =
    name: failures:
    pkgs.writeText "eval-monitor-panel-${name}" (
      if failures == [ ] then "pass" else throw "FAIL: monitor-panel-${name}: ${toString failures}"
    );

  expect = cond: msg: lib.optional (!cond) msg;

  declared = evalWith {
    marchyo.monitors = [
      {
        output = "eDP-1";
        scale = 1.5;
      }
    ];
  };
  declaredLua = luaOf declared;
  offLua = luaOf (evalWith {
    marchyo.monitorPanel.persist = false;
  });

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

  hyprland = (hmOf declared).wayland.windowManager.hyprland.package;
  hyprlandConfig = (hmOf declared).xdg.configFile."hypr/hyprland.lua".source;
in
{
  # Default: the saved-settings loader runs after the declarative monitor rules.
  eval-monitor-panel-loader = check "loader" (
    expect (lib.hasInfix "hyprland-monitor-settings.lua" declaredLua) "loader is not loaded"
    ++ expect (
      indexOf "hyprland-monitor-settings.lua" declaredLua > indexOf "hl.monitor(" declaredLua
    ) "loader does not come after the declarative monitor rules"
  );

  # marchyo.monitorPanel.persist = false leaves the file unread.
  eval-monitor-panel-off = check "off" (
    expect (!(lib.hasInfix "hyprland-monitor-settings.lua" offLua)) "loader loaded with persist off"
    ++ expect (lib.hasInfix "hl.monitor(" offLua) "declarative monitors lost"
  );

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
}
