{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.cli;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      (pkgs.runCommand "marchyo-user-cli" { } ''
        mkdir -p $out/bin
        ln -s ${pkgs.marchyo-cli}/bin/marchyo $out/bin/marchyo
      '')
    ];
  };
}
