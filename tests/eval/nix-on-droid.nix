# nix-on-droid smoke test. The full nix-on-droid system uses builtins.storePath
# and cannot be evaluated in pure `nix flake check`, so this checks the part we
# own — the droid Home-Manager module — resolves against HM 24.05. The full
# activation is built impurely via `just build-nix-on-droid`.
{ helpers, ... }:
let
  inherit (helpers) testDroidHome;
in
{
  eval-nix-on-droid-home = testDroidHome "home" [ ];
}
