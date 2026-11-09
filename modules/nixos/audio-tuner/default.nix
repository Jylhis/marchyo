# Speaker tunings and the omarchy-audio-tuner authoring tools.
#
# The tuning graphs under ./tunings and ./filter-chain-host.conf are taken from
# Omarchy (MIT, Copyright (c) David Heinemeier Hansson). A tuning runs as its
# own PipeWire client (`pipewire -c`), so switching it needs no audio restart
# and a malformed graph cannot stop the daemon.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.audio.tuner;

  # Regex for the physical speaker sink each tuning was measured against.
  tunings = {
    dell-xps-2026 = "^alsa_output.*sof_sdw.*HiFi__Speaker__sink$";
    asus-proart-p14-n1x = "^alsa_output.*mtk_sdw_mc.*HiFi__Speaker__sink$";
    asus-zenbook-a16-ux3607oa = "^alsa_output.*platform-sound.*HiFi__Speaker__sink$";
  };

  sinkName = "omarchy_speaker_tuning";
  configName = "marchyo-speaker-tuning.conf";

  start = pkgs.writeShellApplication {
    name = "marchyo-speaker-tuning-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnused
      pkgs.pulseaudio
      config.services.pipewire.package
    ];
    text = ''
      pattern=$1
      graph=$2
      sink=""
      for _ in $(seq 40); do
        sink=$(pactl list sinks short 2>/dev/null | awk -v p="$pattern" '$2 ~ p {print $2; exit}')
        [ -n "$sink" ] && break
        sleep 0.5
      done
      if [ -z "$sink" ]; then
        echo "no speaker sink matches $pattern" >&2
        exit 1
      fi

      conf="$RUNTIME_DIRECTORY/pipewire"
      mkdir -p "$conf/${configName}.d"
      cp ${./filter-chain-host.conf} "$conf/${configName}"
      sed "s|@SPEAKER_SINK@|$sink|g" "$graph" > "$conf/${configName}.d/90-tuning.conf"

      XDG_CONFIG_HOME=$RUNTIME_DIRECTORY exec pipewire -c ${configName}
    '';
  };

  makeDefault = pkgs.writeShellApplication {
    name = "marchyo-speaker-tuning-default";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.pulseaudio
    ];
    text = ''
      for _ in $(seq 40); do
        if pactl list sinks short 2>/dev/null | cut -f2 | grep -qx ${sinkName}; then
          pactl set-default-sink ${sinkName}
          exit 0
        fi
        sleep 0.25
      done
      echo "tuning sink ${sinkName} never appeared" >&2
      exit 1
    '';
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [ pkgs.omarchy-audio-tuner ];
    })

    {
      assertions = [
        {
          assertion = cfg.profile == null || cfg.enable;
          message = "marchyo.audio.tuner.profile needs marchyo.audio.tuner.enable = true.";
        }
      ];
    }

    (lib.mkIf (cfg.enable && cfg.profile != null) {
      assertions = [
        {
          assertion = builtins.hasAttr cfg.profile tunings;
          message = "marchyo.audio.tuner.profile \"${cfg.profile}\" is unknown; use one of: ${lib.concatStringsSep ", " (lib.attrNames tunings)}";
        }
        {
          assertion = config.services.pipewire.enable;
          message = "marchyo.audio.tuner.profile needs services.pipewire.enable (set marchyo.desktop.enable).";
        }
      ];

      systemd.user.services.marchyo-speaker-tuning = lib.mkIf (builtins.hasAttr cfg.profile tunings) {
        description = "Marchyo speaker tuning filter-chain (${cfg.profile})";
        wantedBy = [ "graphical-session.target" ];
        after = [
          "pipewire.service"
          "wireplumber.service"
        ];
        requires = [ "pipewire.service" ];
        wants = [ "wireplumber.service" ];
        partOf = [ "pipewire.service" ];
        environment.LV2_PATH = "${pkgs.lsp-plugins}/lib/lv2";
        serviceConfig = {
          Type = "simple";
          RuntimeDirectory = "marchyo-speaker-tuning";
          ExecStart = "${start}/bin/marchyo-speaker-tuning-start '${tunings.${cfg.profile}}' ${
            ./tunings + "/${cfg.profile}/filter-chain.conf"
          }";
          ExecStartPost = "${makeDefault}/bin/marchyo-speaker-tuning-default";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    })
  ];
}
