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
  # Reading config.marchyoCliState (top-level, not under marchyo.*) avoids
  # the self-cycle that would arise if the sidecar lived under marchyo.cli:
  # a `marchyo = toMkDefault X` write whose value depends on a `marchyo.*`
  # read forces the module system to evaluate our own contribution before
  # it can decide whether it contributes to marchyo.cli.X. Routing the
  # source through a sibling option breaks the dependency.
  config = mkIf cfg.enable {
    marchyo = toMkDefault config.marchyoCliState;
  };
}
