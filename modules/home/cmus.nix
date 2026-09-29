# Per-user cmus (TUI library audio player). cmus has no single-file MIME handler,
# so xdg.nix registers no audio association for it; it is launched manually.
{
  osConfig ? { },
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled = (osConfig.marchyo.desktop.enable or false) && (defaults.audioPlayer or null) == "cmus";
in
{
  config = lib.mkIf enabled {
    programs.cmus.enable = true;
  };
}
