{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.cli = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = ''
        Whether to install the `marchyo` user CLI system-wide. The CLI lets
        end users inspect their Marchyo configuration, toggle settings, and
        wrap nixos-rebuild. Setting changes are persisted to
        /etc/marchyo/cli-state.json and merged into config.marchyo.* with
        lib.mkDefault priority by the cli-state module.
      '';
    };
  };

  # Declared OUTSIDE `options.marchyo.*` on purpose: cli-state merges this
  # attrset into config.marchyo.* with mkDefault priority, and declaring it
  # under `options.marchyo` would create a self-cycle.
  options.marchyoCliState = mkOption {
    type = types.attrs;
    default = { };
    example = {
      theme.variant = "light";
    };
    description = ''
      State produced by the `marchyo` user CLI, merged into
      config.marchyo.* with `lib.mkDefault` priority so hand-written
      flake config always wins.

      The marchyo flake itself never reads absolute paths, so
      `nix flake check` stays pure. The user CLI writes JSON to
      /etc/marchyo/cli-state.json; to wire it into your system, add
      to your flake.nix:

          marchyoCliState =
            builtins.fromJSON (builtins.readFile /etc/marchyo/cli-state.json);

      and run `nixos-rebuild switch --impure --flake ...`. The
      `marchyo rebuild` CLI command passes `--impure` automatically.
    '';
  };
}
