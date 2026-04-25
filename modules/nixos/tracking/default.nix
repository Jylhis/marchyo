{ config, lib, ... }:
let
  cfg = config.marchyo;
in
{
  imports = [
    ./shell.nix
    ./desktop.nix
    ./editor.nix
    ./git.nix
    ./system.nix
    ./aggregation.nix
    ./analysis.nix
    ./claude-code.nix
  ];

  # When tracking is enabled, auto-enable all collectors except screenshots.
  # Each sub-module uses lib.mkDefault so consumers can still opt out individually.
  config = lib.mkIf cfg.tracking.enable {
    marchyo.tracking = {
      shell.enable = lib.mkDefault true;
      desktop.enable = lib.mkDefault true;
      editor.enable = lib.mkDefault true;
      git.enable = lib.mkDefault true;
      system.auditd = lib.mkDefault true;
      system.fileWatch = lib.mkDefault true;
      aggregation.enable = lib.mkDefault true;
      analysis.enable = lib.mkDefault true;
      # desktop.screenshots.enable is deliberately left false
    };
  };
}
