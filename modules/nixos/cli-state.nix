{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkDefault mkIf;
  cfg = config.marchyo.cli;

  # Reading the JSON sidecar (typically /etc/marchyo/cli-state.json) requires
  # impure flake evaluation. In pure-eval contexts (`nix flake check`)
  # accessing absolute paths outside the flake source tree raises an error;
  # both probes below are wrapped in tryEval so the module evaluates cleanly
  # in either mode and simply produces empty state when the file isn't
  # readable.
  existsProbe = builtins.tryEval (builtins.pathExists cfg.stateFile);
  fileExists = existsProbe.success && existsProbe.value;

  contentProbe = builtins.tryEval (
    if fileExists then builtins.readFile cfg.stateFile else ""
  );
  rawState =
    if fileExists && contentProbe.success && contentProbe.value != "" then
      builtins.fromJSON contentProbe.value
    else
      { };

  # Drop reserved bookkeeping keys (anything starting with "_") before
  # merging into config.marchyo.*.
  state = lib.filterAttrs (n: _: !(lib.hasPrefix "_" n)) rawState;

  # Recursively wrap every leaf in the state with mkDefault so user-written
  # flake configuration always wins over CLI-written values.
  toMkDefault =
    val:
    if builtins.isAttrs val then
      lib.mapAttrs (_: toMkDefault) val
    else
      mkDefault val;
in
{
  config = mkIf cfg.enable {
    marchyo = toMkDefault state;
  };
}
