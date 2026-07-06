# nix-darwin renderer for the unified identity module. Narrower than
# ./nixos.nix by design: nix-darwin's `users.users` carries no
# isNormalUser/isSystemUser, no openssh.authorizedKeys and no
# hashedPasswordFile, so those fields either map differently (sudo →
# `admin` group membership) or fail an assertion (password file, SSH key
# files). Inline `sshAuthorizedKeys` are not rendered on darwin.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  usersLib = import ./lib.nix { inherit lib; };

  # See ./nixos.nix: optionalAttrs (not mkIf) so the `home-manager.users`
  # option path is never referenced on hosts without home-manager.
  homeManagerLoaded = builtins.hasAttr "home-manager" options;

  cfg = config.marchyo.identity;
  hostName = config.networking.hostName;

  enabled = usersLib.filterUsers {
    inherit cfg;
    platform = "darwin";
  };
  local = usersLib.filterUsers {
    inherit cfg;
    platform = "darwin";
    source = "local";
  };
  # Root always exists on macOS and is not managed here.
  nonRootLocal = lib.filterAttrs (name: _: name != "root") local;

  resolveShell =
    u:
    if u.shell == null then
      null
    else if lib.isString u.shell then
      pkgs.${u.shell}
    else
      u.shell;

  defaultHome = u: if u.home != null then u.home else "/Users/${u.username}";

  adminHere = u: u.sudo || lib.elem hostName u.adminOnHosts;
  admins = lib.mapAttrsToList (_: u: u.username) (lib.filterAttrs (_: adminHere) nonRootLocal);

  renderUser =
    name: u:
    lib.filterAttrs (_: v: v != null) {
      # Only define `name` when the login name differs from the attribute
      # name (mirrors ./nixos.nix; avoids fighting the platform default).
      name = if u.username == name then null else u.username;
      description = if u.fullName == "" then null else lib.mkDefault u.fullName;
      uid = if u.uid == null then null else lib.mkDefault u.uid;
      home = lib.mkDefault (defaultHome u);
      shell = if resolveShell u == null then null else lib.mkDefault (resolveShell u);
    };

  renderGroup =
    name: g:
    lib.filterAttrs (_: v: v != null) {
      gid = if g.gid == null then null else lib.mkDefault g.gid;
      members = lib.mkBefore (usersLib.groupMembersOf cfg name);
    };

  hmBindings = lib.filterAttrs (_: u: u.homeManager.enable && u.homeManager.import != null) enabled;

  darwinAssertions = lib.flatten (
    lib.mapAttrsToList (name: u: [
      {
        assertion = u.hashedPasswordFile == null;
        message = "marchyo.identity.users.${name}: hashedPasswordFile is NixOS-only; nix-darwin cannot manage user passwords. Unset it or restrict the user with platforms = [ \"nixos\" ].";
      }
      {
        assertion = u.sshAuthorizedKeyFiles == [ ];
        message = "marchyo.identity.users.${name}: sshAuthorizedKeyFiles is NixOS-only; nix-darwin has no users.users.<name>.openssh options. Unset it or restrict the user with platforms = [ \"nixos\" ].";
      }
    ]) enabled
  );
in
{
  options.marchyo.identity = usersLib.identityOptions;

  config = lib.mkMerge [
    {
      users.users = lib.mapAttrs renderUser nonRootLocal;
      users.groups = lib.mapAttrs renderGroup cfg.groups;
      assertions = usersLib.mkAssertions cfg ++ darwinAssertions;
    }
    (lib.mkIf (admins != [ ]) {
      users.groups.admin.members = lib.mkBefore admins;
    })
    (lib.optionalAttrs homeManagerLoaded {
      home-manager.users = lib.mapAttrs (_: u: {
        imports = [ u.homeManager.import ];
      }) hmBindings;
    })
  ];
}
