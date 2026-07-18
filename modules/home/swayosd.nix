{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  # Linux-only, like every other desktop-gated home module: inert on darwin and
  # on headless hosts, so consumers never need to disabledModules it.
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  osdEnabled = ((osConfig.marchyo or { }).osd or { }).enable or true;
in
{
  config = lib.mkIf (desktopEnabled && osdEnabled) {
    home.packages = [ pkgs.swayosd ];

    # No upstream Home Manager module exists for swayosd - run the server as a
    # hand-rolled user service tied to the graphical session so it restarts
    # with it. Volume/brightness binds in hyprland.nix call swayosd-client.
    systemd.user.services.swayosd = {
      Unit = {
        Description = "SwayOSD OSD server";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.swayosd}/bin/swayosd-server";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
