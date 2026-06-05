{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.darwin.wallpaper;
  inherit (lib)
    hasSuffix
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  lightWallpaper = "${cfg.package}/share/marchyo/wallpapers/jylhis-grid-light.png";
  darkWallpaper = "${cfg.package}/share/marchyo/wallpapers/jylhis-grid-dark.png";

  description = [
    {
      fileName = "marchyo-light.png";
      isPrimary = true;
      isForLight = true;
    }
    {
      fileName = "marchyo-dark.png";
      isForDark = true;
    }
  ];

  descriptionFile = pkgs.writeText "marchyo-wallpaper.json" (builtins.toJSON description);
  manifest = pkgs.writeText "marchyo-wallpaper.manifest" ''
    light=${lightWallpaper}
    dark=${darkWallpaper}
    description=${descriptionFile}
    package=${cfg.package}
    scaling=${cfg.scaling}
  '';

  applyWallpaper = pkgs.writeShellScript "marchyo-apply-wallpaper" ''
    set -eu

    state_dir="${cfg.stateDirectory}"
    mkdir -p "$state_dir"
    exec >> "$state_dir/apply.log" 2>&1

    echo "marchyo-wallpaper: applying $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    install -m 0644 "${lightWallpaper}" "$state_dir/marchyo-light.png"
    install -m 0644 "${darkWallpaper}" "$state_dir/marchyo-dark.png"
    install -m 0644 "${descriptionFile}" "$state_dir/wallpaper.json"

    if ! cmp -s "${manifest}" "$state_dir/manifest"; then
      tmp_name="${cfg.outputName}.tmp.heic"
      rm -f "$state_dir/${cfg.outputName}" "$state_dir/$tmp_name"
      (
        cd "$state_dir"
        "${lib.getExe pkgs.wallpapper}" -i wallpaper.json -o "$tmp_name"
        mv "$tmp_name" "${cfg.outputName}"
      )
      install -m 0644 "${manifest}" "$state_dir/manifest"
    fi

    current="$("${lib.getExe pkgs.desktoppr}" 2>/dev/null || true)"
    if ! printf '%s\n' "$current" | grep -Fxq "$state_dir/${cfg.outputName}"; then
      "${lib.getExe pkgs.desktoppr}" "$state_dir/${cfg.outputName}"
      sleep 1
      "${lib.getExe pkgs.desktoppr}" scale "${cfg.scaling}"
    fi
  '';
in
{
  options.marchyo.darwin.wallpaper = {
    enable = mkEnableOption "generated light/dark macOS wallpaper";

    package = mkOption {
      type = types.package;
      default = pkgs.marchyo-wallpapers;
      defaultText = "pkgs.marchyo-wallpapers";
      description = "Package providing generated Marchyo wallpaper images.";
    };

    scaling = mkOption {
      type = types.enum [
        "fill"
        "stretch"
        "center"
        "fit"
      ];
      default = "fill";
      description = "desktoppr scaling mode for the generated wallpaper.";
    };

    outputName = mkOption {
      type = types.str;
      default = "marchyo-dynamic.heic";
      description = "Generated dynamic wallpaper filename.";
    };

    stateDirectory = mkOption {
      type = types.str;
      default = "${
        config.users.users.${config.system.primaryUser}.home
      }/Library/Application Support/marchyo/wallpaper";
      description = "Per-user directory where the generated HEIC wallpaper is written.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasSuffix ".heic" cfg.outputName;
        message = "marchyo.darwin.wallpaper.outputName must end with .heic.";
      }
    ];

    environment.systemPackages = [
      pkgs.desktoppr
      cfg.package
      pkgs.wallpapper
    ];

    system.defaults.NSGlobalDomain = {
      AppleInterfaceStyle = lib.mkForce null;
      AppleInterfaceStyleSwitchesAutomatically = true;
    };

    home-manager.users.${config.system.primaryUser} = {
      launchd.agents.marchyo-wallpaper = {
        enable = true;
        config = {
          Label = "com.jylhis.marchyo-wallpaper";
          ProgramArguments = [ (toString applyWallpaper) ];
          RunAtLoad = true;
          StartInterval = 3600;
          StandardOutPath = "${cfg.stateDirectory}/apply.log";
          StandardErrorPath = "${cfg.stateDirectory}/apply.log";
        };
      };
    };
  };
}
