# The user-level unfree setting follows the system's nixpkgs.config.allowUnfree.
# The off case is the webapps-notion-no-unfree variant in webapps.nix.
_:
let
  hm = c: c.home-manager.users.testuser;
in
{
  refs.headless.eval-nixpkgs-unfree-user-on =
    c:
    (hm c).home.sessionVariables.NIXPKGS_ALLOW_UNFREE == "1"
    && (hm c).xdg.configFile."nixpkgs/config.nix".text == "{ allowUnfree = true; }"
    && c.nixpkgs.config.allowUnfree;
}
