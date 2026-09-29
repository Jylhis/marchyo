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

  # Runtime shell config, serialized to a generated (read-only) shell.json the
  # shell reads live (Commons/ShellConfig). Empty by default -> no file written,
  # so the shell uses its built-in default bar layout.
  shellSettings = ((osConfig.marchyo or { }).shell or { }).settings or { };

  # Declared shell plugins (build-time Option A), baked into the store shell.
  shellPlugins = ((osConfig.marchyo or { }).shell or { }).plugins or [ ];

  # CLI-added plugins arrive as raw pinned git specs (marchyo.shell.extraPlugins,
  # via the marchyoCliState sidecar). Turn each into a built plugin here, where
  # pkgs is Linux and mkMarchyoShellPlugin exists, and append to the flake's own
  # `plugins` list (never replacing it). name/version are only forwarded when set
  # so the builder's `name ? id` / `version ? "0"` defaults still apply.
  shellExtraPlugins = ((osConfig.marchyo or { }).shell or { }).extraPlugins or [ ];
  builtExtraPlugins = map (
    p:
    pkgs.mkMarchyoShellPlugin (
      {
        src = pkgs.fetchgit { inherit (p) url rev hash; };
        inherit (p) id kinds entryPoints;
      }
      // lib.optionalAttrs (p.name or null != null) { inherit (p) name; }
      // lib.optionalAttrs (p.version or null != null) { inherit (p) version; }
    )
  ) shellExtraPlugins;

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  fontScale = (osConfig.marchyo or { }).theme.fontScale or 1.0;
  # Same voxtypeIndicator derivation as waybar.nix: on when dictation is enabled
  # and its indicator opt-out is left set. Bakes the dictation bar widget in/out.
  dictation = (osConfig.marchyo or { }).dictation or { };
  dictationIndicator = (dictation.enable or false) && (dictation.indicator or true);
  # Same default as waybar.nix: menus on unless explicitly disabled. Drives the
  # battery widget's click target (marchyo menu power vs vicinae toggle).
  menusEnabled = (osConfig.marchyo or { }).menus.enable or true;
  # Arm the solaar HID++ fallback in the peripherals-battery service only when
  # Logitech support is on (Solaar + udev rules are wired by that same flag in
  # modules/nixos/hardware.nix); otherwise the shell never polls solaar.
  peripheralsFallback = ((osConfig.marchyo or { }).hardware or { }).logitech.enable or false;
  # Per-sender notification rules, baked into the shell's NotificationState (no
  # runtime shell config yet). Drop empty match keys so a rule that matches only
  # on appName does not also carry an empty desktopEntry (and vice versa).
  notifRules = map (r: lib.filterAttrs (_n: v: v != "") r) (
    (osConfig.marchyo or { }).notifications.rules or [ ]
  );
  # Palette-independent shell appearance scale axes.
  appearance = (osConfig.marchyo or { }).theme.appearance or { };
  cornerRadiusScale = appearance.cornerRadiusScale or 1.0;
  uiScale = appearance.uiScale or 1.0;
  animationSpeed = appearance.animationSpeed or 1.0;
  highContrast = appearance.highContrast or false;
  # Theme + scale the store package to the host at build time — declarative, no
  # activation-time file writes. Runtime theme switching is deferred.
  shellPkg = pkgs.marchyo-shell.override {
    variant = themeVariant;
    inherit
      fontScale
      dictationIndicator
      menusEnabled
      peripheralsFallback
      notifRules
      cornerRadiusScale
      uiScale
      animationSpeed
      highContrast
      ;
    plugins = shellPlugins ++ builtExtraPlugins;
  };
in
{
  config = lib.mkIf (desktopEnabled && shellEnabled) {
    home.packages = [ shellPkg ];

    # Generated, read-only runtime config. Only written when the host set
    # anything, so an untouched host keeps the shell's built-in default layout.
    xdg.configFile."marchyo/shell.json" = lib.mkIf (shellSettings != { }) {
      text = builtins.toJSON shellSettings;
    };

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
