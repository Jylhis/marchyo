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
  # Opt-in: unlike osd/menus this defaults off (Phase 0 spike runs alongside the
  # discrete stack), so no `or true` fallback.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  # Theme the store package to the host's variant at build time — declarative,
  # no activation-time file writes. Runtime theme switching is deferred.
  shellPkg = pkgs.marchyo-shell.override { variant = themeVariant; };
in
{
  config = lib.mkIf (desktopEnabled && shellEnabled) {
    home.packages = [ shellPkg ];

    # Run the shell as a user service tied to the graphical session so it
    # restarts with it (same shape as swayosd.nix).
    systemd.user.services.marchyo-shell = {
      Unit = {
        Description = "Marchyo Quickshell desktop shell";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe shellPkg;
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
