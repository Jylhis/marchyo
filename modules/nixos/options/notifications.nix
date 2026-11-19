{ config, lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.notifications = {
    unitFailures = {
      enable = mkOption {
        type = types.bool;
        default = config.marchyo.desktop.enable;
        defaultText = lib.literalExpression "config.marchyo.desktop.enable";
        example = false;
        description = ''
          Follow the journal and send a critical notification when a system or
          user unit fails. The "Show log" action opens `journalctl -b -u <unit>`
          in a terminal. A user who cannot read the system journal (outside
          `wheel`, `adm` and `systemd-journal`) sees only the failures of their own
          user units.
        '';
      };

      ignore = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "app-*.scope"
          "flatpak-*"
        ];
        description = ''
          Shell glob patterns matched against the full unit name (for example
          `foo.service`). Failures of matching units are not announced. A unit
          is announced at most once per minute.
        '';
      };
    };

    stackBySender = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Group visible toasts into decks by sender (per site for browser
        notifications). A deck expands on hover. Identical repeats collapse into
        one toast with a count. Only used when `marchyo.shell.enable` is set.
      '';
    };

    detectCodes = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Detect verification codes in notifications. A toast with a code gets a
        Copy button, and the notification passes do-not-disturb.
      '';
    };

    passApps = mkOption {
      type = types.listOf types.str;
      default = [ "marchyo" ];
      example = [
        "marchyo"
        "Calendar"
      ];
      description = ''
        Application names (exact, case-insensitive) whose notifications pass
        do-not-disturb. Critical notifications always pass.
      '';
    };

    # Baked into the shell at build time; ignored when the shell is off.
    # Plain str/bool/int only.
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
