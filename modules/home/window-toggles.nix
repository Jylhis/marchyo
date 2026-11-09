# The recorder/notify tools the marchyo CLI drives for the capture and window
# binds in lib/keybinds.nix, and the pop-out re-centring hook.
{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && osConfig.marchyo.desktop.enable;
in
{
  config = lib.mkIf desktopEnabled {
    home.packages = [
      # Tools `marchyo capture record` drives (the CLI shells out to them).
      pkgs.gpu-screen-recorder
      pkgs.slurp
      pkgs.libnotify
      pkgs.procps
    ];

    # Window utilities (`marchyo window pop|close-all|tiled-fullscreen`, `marchyo toggle
    # gaps|fullscreen-desktop`). The Appearance menu lists them all.
    wayland.windowManager.hyprland.settings.on = [
      # A floating window moved to another monitor keeps its offset, so a popped-out
      # window is centred again once it lands. The dispatcher move fires before the
      # window changes monitor, so the centring waits one loop.
      {
        _args = [
          "window.move_to_workspace"
          (hlua.mkLuaInline ''
            function(window, workspace)
              if not (window and workspace and window.monitor and workspace.monitor) then return end
              if window.monitor.id == workspace.monitor.id then return end
              local popped = false
              for _, tag in ipairs(window.tags or {}) do
                if tag == "pop" then popped = true end
              end
              if not popped then return end
              local target = "address:" .. window.address
              hl.timer(function()
                hl.dispatch(hl.dsp.window.center({ window = target }))
              end, { timeout = 1, type = "oneshot" })
            end'')
        ];
      }
    ];

  };
}
