# Dictation backends other than voxtype (which modules/home/voxtype.nix owns),
# plus the backend hint `marchyo dictation` reads. Gated on
# marchyo.dictation.enable; Linux-only (Wayland dictation).
#
# - superwhisper: user service plus a login oneshot that runs the package's
#   setup-user once per package version and keeps the app's own shortcuts off
#   marchyo's keys (Alt+Space and F9 are Hyprland binds).
# - hex: user service plus a oneshot that installs the speech model once.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = (osConfig.marchyo or { }).dictation or { };
  enabled = pkgs.stdenv.hostPlatform.isLinux && (cfg.enable or false);
  backend = cfg.backend or "superwhisper";

  inherit (pkgs) superwhisper;
  hex = pkgs.hex-dictation;

  # setup-user calls omarchy-shell to register a bar panel; marchyo has none.
  omarchyShellStub = pkgs.writeShellScriptBin "omarchy-shell" "exit 0";

  superwhisperSetup = pkgs.writeShellApplication {
    name = "marchyo-superwhisper-setup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
      omarchyShellStub
      superwhisper
    ];
    text = ''
      stamp="''${XDG_STATE_HOME:-$HOME/.local/state}/marchyo/superwhisper-setup"
      mkdir -p "$(dirname "$stamp")"
      if [ "$(cat "$stamp" 2>/dev/null || true)" != "${superwhisper}" ]; then
        if ${superwhisper}/share/superwhisper/setup-user; then
          printf '%s' "${superwhisper}" > "$stamp"
        else
          echo "superwhisper setup-user failed; shortcuts are still applied" >&2
        fi
      fi

      for _ in $(seq 50); do
        superwhisper status >/dev/null 2>&1 && break
        sleep 0.2
      done

      shortcuts=$(superwhisper shortcuts show)
      if [ "$(jq -r '.shortcuts.toggle // empty' <<<"$shortcuts")" != "Ctrl+Alt+Space" ]; then
        superwhisper shortcuts set toggle "Ctrl+Alt+Space" >/dev/null
      fi
      hold=$(jq -r '.shortcuts.hold // empty' <<<"$shortcuts")
      if [ -n "$hold" ] && [ "$hold" != "none" ]; then
        superwhisper shortcuts set hold none >/dev/null
      fi
    '';
  };

  hexModelInstall = pkgs.writeShellApplication {
    name = "marchyo-hex-model-install";
    runtimeInputs = [ hex ];
    text = ''
      hex model status >/dev/null 2>&1 || hex model install
    '';
  };
in
{
  config = lib.mkIf enabled (
    lib.mkMerge [
      {
        xdg.configFile."marchyo/dictation.json".text = builtins.toJSON { inherit backend; };
        home.packages = [
          pkgs.wl-clipboard
          pkgs.wtype
        ];
      }

      (lib.mkIf (backend == "superwhisper") {
        systemd.user.services.superwhisper = {
          Unit = {
            Description = "Superwhisper dictation";
            After = [
              "graphical-session.target"
              "pipewire.service"
            ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${lib.getExe superwhisper} daemon";
            ExecStopPost = "${lib.getExe superwhisper} playback-restore";
            Restart = "on-failure";
            RestartSec = 2;
            KillMode = "control-group";
            TimeoutStopSec = 15;
            UMask = "0077";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        systemd.user.services.superwhisper-setup = {
          Unit = {
            Description = "Superwhisper first-run setup and shortcuts";
            After = [
              "graphical-session.target"
              "superwhisper.service"
            ];
            Wants = [ "superwhisper.service" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.getExe superwhisperSetup;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })

      (lib.mkIf (backend == "hex") {
        home.packages = [ hex ];

        systemd.user.services.hex = {
          Unit = {
            Description = "Hex background dictation";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
            StartLimitIntervalSec = 60;
            StartLimitBurst = 5;
          };
          Service = {
            Type = "notify";
            NotifyAccess = "main";
            ExecStart = "${lib.getExe hex} service";
            EnvironmentFile = "-%h/.local/share/hex/session.env";
            Restart = "on-failure";
            RestartSec = 3;
            TimeoutStopSec = 30;
            UMask = "0077";
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };

        systemd.user.services.hex-model = {
          Unit = {
            Description = "Install the Hex speech model";
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.getExe hexModelInstall;
          };
          Install.WantedBy = [ "graphical-session.target" ];
        };
      })
    ]
  );
}
