{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  # Linux-only, like every other desktop-gated home module: inert on darwin and
  # on headless hosts, so consumers never need to disabledModules it.
  desktopEnabled =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  # Opt-in: unlike osd/menus this defaults off (Phase 0 spike runs alongside the
  # discrete stack), so no `or true` fallback.
  shellEnabled = ((osConfig.marchyo or { }).shell or { }).enable or false;

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  fontScale = (osConfig.marchyo or { }).theme.fontScale or 1.0;
  # Same voxtypeIndicator derivation as waybar.nix: on when dictation is enabled
  # and its indicator opt-out is left set. Bakes the dictation bar widget in/out.
  dictation = (osConfig.marchyo or { }).dictation or { };
  dictationIndicator = (dictation.enable or false) && (dictation.indicator or true);
  # Same default as waybar.nix: menus on unless explicitly disabled. Drives the
  # battery widget's click target (marchyo menu power vs vicinae toggle).
  menusEnabled = (osConfig.marchyo or { }).menus.enable or true;
  # Theme + scale the store package to the host at build time — declarative, no
  # activation-time file writes. Runtime theme switching is deferred.
  shellPkg = pkgs.marchyo-shell.override {
    variant = themeVariant;
    inherit fontScale dictationIndicator menusEnabled;
  };
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
