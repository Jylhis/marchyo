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
        Adds `eval "$(wt config shell init bash)"` to bash initialization.
      '';
    };

    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.zsh.enable;
      defaultText = lib.literalExpression "config.programs.zsh.enable";
      description = ''
        Enable Zsh shell integration for directory switching with `wt switch`.
        Adds `eval "$(wt config shell init zsh)"` to zsh initialization.
      '';
    };

    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.fish.enable;
      defaultText = lib.literalExpression "config.programs.fish.enable";
      description = ''
        Enable Fish shell integration for directory switching with `wt switch`.
        Adds `wt config shell init fish | source` to fish initialization.
      '';
    };
    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = ''
        Configuration written to {file}`$XDG_CONFIG_HOME/worktrunk/config.toml`.

        See <https://worktrunk.dev/config/> for
        available options and documentation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Bash integration
    programs.bash.initExtra = lib.mkIf cfg.enableBashIntegration ''
      # Worktrunk shell integration
      eval "$(${lib.getExe cfg.package} config shell init bash)"
    '';

    # Zsh integration
    programs.zsh.initExtra = lib.mkIf cfg.enableZshIntegration ''
      # Worktrunk shell integration
      eval "$(${lib.getExe cfg.package} config shell init zsh)"
    '';

    # Fish integration
    programs.fish.interactiveShellInit = lib.mkIf cfg.enableFishIntegration ''
      # Worktrunk shell integration
      ${lib.getExe cfg.package} config shell init fish | source
    '';

    xdg.configFile."worktrunk/config.toml" = lib.mkIf (cfg.settings != { }) {
      source = tomlFormat.generate "config.toml" cfg.settings;
    };
  };
}
