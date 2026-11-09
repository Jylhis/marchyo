# The backend hint `marchyo dictation` reads and the typing tools it uses.
# The voxtype daemon itself lives in modules/home/voxtype.nix. Gated on
# marchyo.dictation.enable; Linux-only (Wayland dictation).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = (osConfig.marchyo or { }).dictation or { };
  enabled = pkgs.stdenv.hostPlatform.isLinux && (cfg.enable or false);
  backend = cfg.backend or "voxtype";
in
{
  config = lib.mkIf enabled {
    xdg.configFile."marchyo/dictation.json".text = builtins.toJSON { inherit backend; };
    home.packages = [
      pkgs.wl-clipboard
      pkgs.wtype
    ];
  };
}
