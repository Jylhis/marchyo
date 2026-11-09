# Feature-gated: marchyo.slack.enable.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.slack;
  format = pkgs.formats.json { };

  # Chromium's remote-debugging pipe is how the launcher applies the theme, so
  # it only exists behind marchyo.slack.themeInjection.enable.
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  launcher = pkgs.writeShellScriptBin "marchyo-slack" ''
    export GI_TYPELIB_PATH=${pkgs.glib.out}/lib/girepository-1.0
    export MARCHYO_SLACK_BIN=${cfg.package}/bin/slack
    export MARCHYO_SLACK_LAUNCHER=marchyo-slack
    exec ${python}/bin/python ${./slack-theme/launcher.py} "$@"
  '';
  themedSlack = pkgs.symlinkJoin {
    name = "slack-marchyo-themed";
    paths = [
      cfg.package
      launcher
    ];
    postBuild = ''
      for f in $out/share/applications/slack.desktop; do
        [ -e "$f" ] || continue
        cp --remove-destination "$(readlink -f "$f")" "$f"
        sed -i -E 's|^Exec=[^ ]*|Exec=marchyo-slack|' "$f"
      done
    '';
  };

in
{
  options.marchyo.slack.themeInjection.enable = lib.mkEnableOption ''
    Slack theme injection. Slack starts through `marchyo-slack`, which opens a
    Chromium remote-debugging pipe (no port or socket) and applies the current
    theme's colours with Slack's own preference actions. The menu entry uses
    the launcher. Off by default because it drives Slack internals
  '';

  options.programs.slack = {
    enable = lib.mkEnableOption "Slack";
    package = lib.mkPackageOption pkgs "slack" { };
    settings = lib.mkOption {
      description = "https://slack.com/intl/en-gb/help/articles/11906214948755-Manage-desktop-app-configurations#linux-1";
      default = { };
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          ClientEnvironment = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Configures the client to run in either commercial mode or government compliance mode";
          };
          DefaultSignInTeam = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Sets a default workspace or org URL for users to sign in to on first launch";
          };
          DownloadPath = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            default = null;
            description = "Configures a download location.";
          };
          HardwareAcceleration = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enables or disables hardware accelerated rendering on the client";
          };
        };
      };
    };

  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (if config.marchyo.slack.themeInjection.enable then themedSlack else cfg.package)
    ];

    # https://slack.com/help/articles/11906214948755-Manage-desktop-app-configurations#linux-2
    environment.etc."slack-desktop.conf" = {
      enable = true;
      source = format.generate "slack-desktop.conf" (
        lib.filterAttrs (_name: value: value != null) cfg.settings
      );
      mode = "0444";
    };
  };
}
