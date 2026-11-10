{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  # Desktop-gated, so inert on headless hosts.
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && osConfig.marchyo.desktop.enable;
  # modules/nixos/desktop-config.nix turns the shell on with the desktop; an
  # osConfig without the option (standalone HM) keeps the discrete stack.
  shellEnabled = osConfig.marchyo.shell.enable;

  # Unset typed keys (null) and the empty submodules they leave behind are
  # dropped, so shell.json carries only what the host set. Empty by default, so
  # no file is written and the shell keeps its default layout.
  pruneSettings =
    v:
    if builtins.isAttrs v then
      lib.filterAttrs (_: x: x != null && x != { }) (lib.mapAttrs (_: pruneSettings) v)
    else if builtins.isList v then
      map pruneSettings v
    else
      v;
  diskWarnPercent = osConfig.marchyo.shell.diskWarnPercent;
  shellSettings = lib.recursiveUpdate (pruneSettings osConfig.marchyo.shell.settings) (
    lib.optionalAttrs (diskWarnPercent != 10) { health.diskWarnPercent = diskWarnPercent; }
  );

  shellPlugins = osConfig.marchyo.shell.plugins;

  # CLI-added plugins arrive as raw pinned git specs; build each here (Linux pkgs,
  # mkMarchyoShellPlugin available) and append to the flake's own `plugins` list.
  # name/version are only forwarded when set so the builder's defaults still apply.
  # `source` records the pin in the shell's plugins.lock.json.
  shellExtraPlugins = osConfig.marchyo.shell.extraPlugins;
  builtExtraPlugins = map (
    p:
    pkgs.mkMarchyoShellPlugin (
      {
        src = pkgs.fetchgit { inherit (p) url rev hash; };
        inherit (p) id kinds entryPoints;
        prefix = p.prefix or null;
        source = { inherit (p) url rev; };
      }
      // lib.optionalAttrs (p.name or null != null) { inherit (p) name; }
      // lib.optionalAttrs (p.version or null != null) { inherit (p) version; }
    )
  ) shellExtraPlugins;

  themeVariant = osConfig.marchyo.theme.variant;
  fontScale = osConfig.marchyo.theme.fontScale;
  # Bakes the dictation bar widget in/out (on when dictation and its indicator are set).
  dictation = osConfig.marchyo.dictation;
  dictationIndicator = dictation.enable && dictation.indicator;
  dictationBackend = dictation.backend;
  # Drives the power panel's menu button (marchyo menu power vs the in-shell launcher).
  menusEnabled = osConfig.marchyo.menus.enable;
  # Arm the solaar HID++ fallback only when Logitech support is on; otherwise
  # the shell never polls solaar.
  peripheralsFallback = osConfig.programs.solaar.enable;
  # Bake the tailscale CLI in only when the service is on, to keep it out of the
  # closure on hosts that do not enable it.
  tailscaleEnabled = osConfig.services.tailscale.enable;
  # Drop empty match keys so a rule matching only on appName does not also carry
  # an empty desktopEntry (and vice versa).
  notifRules = map (r: lib.filterAttrs (_n: v: v != "") r) osConfig.marchyo.notifications.rules;
  notifOpts = osConfig.marchyo.notifications;
  notifStackBySender = notifOpts.stackBySender;
  notifDetectCodes = notifOpts.detectCodes;
  notifPassApps = notifOpts.passApps;
  language = osConfig.marchyo.language;
  perMonitorWorkspaces = osConfig.marchyo.workspaces.perMonitor;
  monitorPersist = osConfig.marchyo.monitorPanel.persist;
  appearance = osConfig.marchyo.theme.appearance;
  inherit (appearance)
    cornerRadiusScale
    uiScale
    animationSpeed
    highContrast
    reduceMotion
    floatingBar
    surfaceAlpha
    ;
  # Theme + scale the store package at build time (no activation-time file writes).
  shellPkg = pkgs.marchyo-shell.override {
    variant = themeVariant;
    inherit
      fontScale
      dictationIndicator
      dictationBackend
      menusEnabled
      peripheralsFallback
      notifRules
      notifStackBySender
      notifDetectCodes
      notifPassApps
      cornerRadiusScale
      uiScale
      animationSpeed
      reduceMotion
      highContrast
      floatingBar
      surfaceAlpha
      tailscaleEnabled
      language
      perMonitorWorkspaces
      monitorPersist
      ;
    plugins = shellPlugins ++ builtExtraPlugins;
  };
in
{
  config = lib.mkIf (desktopEnabled && shellEnabled) {
    home.packages = [ shellPkg ];

    # Only written when the host set anything, so an untouched host keeps the default layout.
    xdg.configFile."marchyo/shell.json" = lib.mkIf (shellSettings != { }) {
      text = builtins.toJSON shellSettings;
    };

    # User service tied to the graphical session so it restarts with it.
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
