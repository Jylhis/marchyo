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
    # marchyo-cli ships both binaries (`marchyo`, `marchyoctl`) but the
    # mainProgram metadata points at `marchyo`, the user-facing one. End-user
    # systems typically don't want the dev CLI on PATH; gate it behind
    # marchyo.cli.dev.enable in a future iteration if needed.
    environment.systemPackages = [ pkgs.marchyo-cli ];
  };
}
