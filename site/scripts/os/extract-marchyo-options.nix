# Extracts the `marchyo.*` option declarations from a marchyo checkout as JSON.
# Used by scripts/os/seed-options.mjs to (re)generate src/os/data/marchyo-options.json.
#
#   nix-instantiate --eval --strict --json scripts/os/extract-marchyo-options.nix \
#     --arg nixpkgs <path> --arg marchyo <path> --argstr platform nixos
#
# platform is the marchyo modules/<dir> name: nixos | home | darwin.
{
  nixpkgs,
  marchyo,
  platform,
}:
let
  lib = import (nixpkgs + "/lib");
  pkgs = import nixpkgs {
    system = "x86_64-linux";
    config = { };
    overlays = [ ];
  };

  # Host namespaces marchyo modules read from but never declare (the real host
  # module system provides them). Typed `anything` with a throwing default so a
  # default that dereferences them fails catchably inside `safe` below instead
  # of aborting the whole evaluation with an uncatchable missing-attribute.
  hostStubs =
    { lib, ... }:
    {
      options = lib.genAttrs [ "users" "system" "home" ] (
        name:
        lib.mkOption {
          type = lib.types.anything;
          default = throw "extract-stub: host option ${name} is not available here";
        }
      );
      # Priority 0 beats every module's definition, so reading any of these
      # namespaces forces the throw (catchable) rather than yielding a partial
      # attrset whose missing attributes abort uncatchably.
      config = lib.genAttrs [ "users" "system" "home" ] (
        name: lib.mkOverride 0 (throw "extract-stub: host config ${name} is not available here")
      );
    };

  eval = lib.evalModules {
    modules = [
      (marchyo + "/modules/${platform}")
      hostStubs
      { _module.check = false; }
    ];
    specialArgs = {
      inherit pkgs;
      osConfig = { };
    };
  };

  # tryEval only catches throw/assert, so deepSeq inside the try to surface
  # laziness now; anything unrenderable becomes null instead of aborting.
  safe =
    v:
    let
      r = builtins.tryEval (builtins.deepSeq v v);
    in
    if r.success then r.value else null;

  renderDefault =
    d:
    if !(d ? default) then
      null
    else
      safe (
        if lib.isAttrs d.default && d.default ? text then
          builtins.toString d.default.text
        else
          builtins.toJSON d.default
      );

  docs = lib.optionAttrSetToDocList eval.options;
in
map (d: {
  inherit (d) name;
  description = safe (d.description or null);
  option_type = safe (d.type or null);
  default_value = renderDefault d;
}) (builtins.filter (d: lib.hasPrefix "marchyo." d.name && (d.visible or true)) docs)
