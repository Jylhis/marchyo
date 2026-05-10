{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkIf;
  cfg = config.marchyo.cli;

  # Recursively wrap every leaf in the state with mkDefault so user-written
  # flake configuration always wins over CLI-written values.
  toMkDefault =
    val: if builtins.isAttrs val then lib.mapAttrs (_: toMkDefault) val else mkDefault val;
in
{
  config = mkIf cfg.enable {
    marchyo = toMkDefault cfg.persistedState;
  };
}
