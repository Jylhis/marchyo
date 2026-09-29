{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  # Linux-only and desktop-gated: inert on darwin and headless hosts.
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  osdEnabled = ((osConfig.marchyo or { }).osd or { }).enable or true;
  # The unified shell provides its own OSD (shell/Osd), so SwayOSD stands down when it is on.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;
in
{
  config = lib.mkIf (desktopEnabled && osdEnabled && !shellEnabled) {
    home.packages = [ pkgs.swayosd ];

    # No upstream HM module for swayosd; run the server as a user service tied
    # to the graphical session. Volume/brightness binds in hyprland.nix call swayosd-client.
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
