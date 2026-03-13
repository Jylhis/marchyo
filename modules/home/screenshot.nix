{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  cfg = config.marchyo.screenshot;
in
{
  options.marchyo.screenshot = {
    enable = mkEnableOption "Screenshot functionality" // {
      default = true;
    };

    enableAnnotation = mkOption {
      type = types.bool;
      default = true;
      description = "Enable satty for screenshot annotation";
    };
  };

  config = mkIf cfg.enable {
    # Install annotation tool
    home.packages = lib.optionals cfg.enableAnnotation (
      with pkgs;
      [
        satty # Screenshot annotation tool
      ]
    );
  };
}
