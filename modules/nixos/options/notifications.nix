{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.notifications = {
    # Baked into the shell at build time; ignored when the shell is off (mako
    # owns notifications then). Plain str/bool/int only, per the darwin eval gate.
    rules = mkOption {
      default = [ ];
      example = [
        {
          appName = "Slack";
          bypassDnd = true;
        }
        {
          desktopEntry = "org.telegram.desktop";
          saveHistory = false;
        }
      ];
      description = ''
        Per-sender notification rules for the Marchyo shell. Each rule matches a
        notification by `appName` and/or `desktopEntry` (exact, case-insensitive;
        first matching rule wins) and overrides how it is handled. Only used when
        `marchyo.shell.enable` is set.
      '';
      type = types.listOf (
        types.submodule {
          options = {
            appName = mkOption {
              type = types.str;
              default = "";
              example = "Slack";
              description = "Match the notification's application name (exact, case-insensitive).";
            };
            desktopEntry = mkOption {
              type = types.str;
              default = "";
              example = "org.telegram.desktop";
              description = "Match the notification's desktop-entry id (exact, case-insensitive).";
            };
            showToast = mkOption {
              type = types.bool;
              default = true;
              description = "Show an on-screen toast. Set false to keep the sender in history but suppress its popup.";
            };
            saveHistory = mkOption {
              type = types.bool;
              default = true;
              description = "Record the notification in the notification-centre history.";
            };
            bypassDnd = mkOption {
              type = types.bool;
              default = false;
              description = "Show the toast even while do-not-disturb is on.";
            };
            overrideDuration = mkOption {
              type = types.int;
              default = -1;
              example = 10000;
              description = "Override the toast timeout in milliseconds. -1 keeps the sender/urgency default; 0 means never expire.";
            };
          };
        }
      );
    };
  };
}
