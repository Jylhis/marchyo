{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.slack;
  format = pkgs.formats.json { };

in
{
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

    environment.systemPackages = [ cfg.package ];
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
