# Per-monitor workspaces (the default) and the global numbering
# (desktop-tweaks-3: marchyo.workspaces.perMonitor = false). The marchyo.monitors
# order of desktop-tweaks-4 (tests/eval/monitors.nix) seeds the blocks.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind;

  hmOf = c: c.home-manager.users.testuser;
  settingsOf = c: (hmOf c).wayland.windowManager.hyprland.settings;
  luaOf = c: (hmOf c).xdg.configFile."hypr/hyprland.lua".text;

  expect = cond: msg: lib.optional (!cond) msg;
in
{
  refs = {
    # Default: the Lua module is loaded and Super+1..0 act on the monitor's block.
    desktop.eval-workspaces-per-monitor =
      c:
      let
        settings = settingsOf c;
        binds = settings.bind;
        lua = luaOf c;
      in
      expect (lib.hasInfix "local marchyoWorkspaces = (dofile(" lua) "hyprland.lua does not load the module"
      ++ expect (lib.hasInfix "hyprland-monitor-workspaces.lua" lua) "module path missing"
      ++ expect (!(settings ? workspace_rule)) "workspace_rule should be gone"
      ++ expect (hyprHasBind binds "SUPER + code:10" "marchyoWorkspaces.focus(1)") "SUPER+1"
      ++ expect (hyprHasBind binds "SUPER + code:19" "marchyoWorkspaces.focus(10)") "SUPER+0"
      ++ expect (hyprHasBind binds "SUPER + SHIFT + code:12"
        "marchyoWorkspaces.move_window(3)"
      ) "SUPER+SHIFT+3"
      ++ expect (hyprHasBind binds "SUPER + SHIFT + ALT + code:14"
        "marchyoWorkspaces.move_window(5, false)"
      ) "SUPER+SHIFT+ALT+5"
      ++ expect (hyprHasBind binds "SUPER + TAB" "m+1") "SUPER+TAB"
      ++ expect (hyprHasBind binds "SUPER + SHIFT + TAB" "m-1") "SUPER+SHIFT+TAB"
      ++ expect (hyprHasBind binds "SUPER + CTRL + TAB" "previous_per_monitor") "SUPER+CTRL+TAB"
      ++ expect (hyprHasBind binds "SUPER + SHIFT + ALT + left"
        "marchyoWorkspaces.move_to_monitor(\"l\")"
      ) "move workspace left"
      ++ expect (!(hyprHasBind binds "SUPER + 1" "on_current_monitor")) "global SUPER+1 still bound";

    # The marchyo.monitors order seeds the blocks; disabled outputs (HDMI-A-1)
    # are skipped.
    desktop-tweaks-4.eval-workspaces-seed =
      c: expect (lib.hasInfix ''({ "DP-2", "eDP-1", "DP-1" })'' (luaOf c)) "seed list not rendered";

    # perMonitor = false keeps the global numbering.
    desktop-tweaks-3.eval-workspaces-global =
      c:
      let
        settings = settingsOf c;
        binds = settings.bind;
      in
      expect (!(settings ? marchyoWorkspaces)) "module loaded with perMonitor off"
      ++ expect (settings ? workspace_rule) "workspace_rule missing"
      ++ expect (hyprHasBind binds "SUPER + 1" "on_current_monitor = true") "SUPER+1"
      ++ expect (hyprHasBind binds "SUPER + SHIFT + code:10"
        "window.move({ workspace = 1 })"
      ) "SUPER+SHIFT+1"
      ++ expect (hyprHasBind binds "SUPER + TAB" "e+1") "SUPER+TAB"
      ++ expect (hyprHasBind binds "SUPER + CTRL + TAB" "\"previous\"") "SUPER+CTRL+TAB"
      ++ expect (!(hyprHasBind binds "SUPER + code:10" "marchyoWorkspaces")) "per-monitor bind leaked";
  };

  refConfig.desktop-tweaks-3.marchyo.workspaces.perMonitor = false;
}
