# Declarations only; configuration lives in modules/home/tmux.nix.
{ config, lib, ... }:
{
  options.marchyo.tmux.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.marchyo.development.enable;
    defaultText = lib.literalExpression "config.marchyo.development.enable";
    example = false;
    description = ''
      Themed tmux: mouse, true colour, vi copy mode, 1-based windows and the
      Marchyo status, pane and message colours. On a desktop the colours follow
      `marchyo theme` and a running server reloads them on a switch. Defaults
      to on when `marchyo.development.enable` is set.
    '';
  };
}
