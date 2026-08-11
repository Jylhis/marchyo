{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.worktrunk;
  tomlFormat = pkgs.formats.toml { };
in
{
  options.programs.worktrunk = {
    enable = lib.mkEnableOption "worktrunk";

    package = lib.mkPackageOption pkgs "worktrunk" { };

    enableBashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.bash.enable;
      defaultText = lib.literalExpression "config.programs.bash.enable";
      description = ''
        Enable Bash shell integration for directory switching with `wt switch`.
      '';
    };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = ''
        Configuration written to {file}`$XDG_CONFIG_HOME/worktrunk/config.toml`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    programs.bash.initExtra = lib.mkIf cfg.enableBashIntegration ''
      eval "$(${lib.getExe cfg.package} config shell init bash)"
    '';

    xdg.configFile."worktrunk/config.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "config.toml" cfg.settings;
    };
  };
}
