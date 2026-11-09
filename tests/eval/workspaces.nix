{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind;

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

  hmOf = extra: (evalWith extra).config.home-manager.users.testuser;
  settingsOf = extra: (hmOf extra).wayland.windowManager.hyprland.settings;
  luaOf = extra: (hmOf extra).xdg.configFile."hypr/hyprland.lua".text;

  check =
    name: failures:
    pkgs.writeText "eval-workspaces-${name}" (
      if failures == [ ] then "pass" else throw "FAIL: workspaces-${name}: ${toString failures}"
    );

  expect = cond: msg: lib.optional (!cond) msg;

  onSettings = settingsOf { };
  onBinds = onSettings.bind;
  onLua = luaOf { };

  offSettings = settingsOf { marchyo.workspaces.perMonitor = false; };
  offBinds = offSettings.bind;

  seededLua = luaOf {
    marchyo.monitors = [
      { output = "DP-2"; }
      {
        output = "HDMI-A-1";
        enable = false;
      }
      { output = "eDP-1"; }
    ];
  };
in
{
  # Default: the Lua module is loaded and Super+1..0 act on the monitor's block.
  eval-workspaces-per-monitor = check "per-monitor" (
    expect (lib.hasInfix "local marchyoWorkspaces = (dofile(" onLua) "hyprland.lua does not load the module"
    ++ expect (lib.hasInfix "hyprland-monitor-workspaces.lua" onLua) "module path missing"
    ++ expect (!(onSettings ? workspace_rule)) "workspace_rule should be gone"
    ++ expect (hyprHasBind onBinds "SUPER + code:10" "marchyoWorkspaces.focus(1)") "SUPER+1"
    ++ expect (hyprHasBind onBinds "SUPER + code:19" "marchyoWorkspaces.focus(10)") "SUPER+0"
    ++ expect (hyprHasBind onBinds "SUPER + SHIFT + code:12"
      "marchyoWorkspaces.move_window(3)"
    ) "SUPER+SHIFT+3"
    ++ expect (hyprHasBind onBinds "SUPER + SHIFT + ALT + code:14"
      "marchyoWorkspaces.move_window(5, false)"
    ) "SUPER+SHIFT+ALT+5"
    ++ expect (hyprHasBind onBinds "SUPER + TAB" "m+1") "SUPER+TAB"
    ++ expect (hyprHasBind onBinds "SUPER + SHIFT + TAB" "m-1") "SUPER+SHIFT+TAB"
    ++ expect (hyprHasBind onBinds "SUPER + CTRL + TAB" "previous_per_monitor") "SUPER+CTRL+TAB"
    ++ expect (hyprHasBind onBinds "SUPER + SHIFT + ALT + left"
      "marchyoWorkspaces.move_to_monitor(\"l\")"
    ) "move workspace left"
    ++ expect (!(hyprHasBind onBinds "SUPER + 1" "on_current_monitor")) "global SUPER+1 still bound"
  );

  # The marchyo.monitors order seeds the blocks; disabled outputs are skipped.
  eval-workspaces-seed = check "seed" (
    expect (lib.hasInfix ''({ "DP-2", "eDP-1" })'' seededLua) "seed list not rendered"
  );

  # perMonitor = false keeps the global numbering.
  eval-workspaces-global = check "global" (
    expect (!(offSettings ? marchyoWorkspaces)) "module loaded with perMonitor off"
    ++ expect (offSettings ? workspace_rule) "workspace_rule missing"
    ++ expect (hyprHasBind offBinds "SUPER + 1" "on_current_monitor = true") "SUPER+1"
    ++ expect (hyprHasBind offBinds "SUPER + SHIFT + code:10"
      "window.move({ workspace = 1 })"
    ) "SUPER+SHIFT+1"
    ++ expect (hyprHasBind offBinds "SUPER + TAB" "e+1") "SUPER+TAB"
    ++ expect (hyprHasBind offBinds "SUPER + CTRL + TAB" "\"previous\"") "SUPER+CTRL+TAB"
    ++ expect (!(hyprHasBind offBinds "SUPER + code:10" "marchyoWorkspaces")) "per-monitor bind leaked"
  );
}
