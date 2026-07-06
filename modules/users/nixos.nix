# NixOS renderer for the unified identity module. Renders
# `marchyo.identity.users`/`.groups` (see ./lib.nix for the contract) into
# `users.users`, `users.groups` and — when the host imports home-manager —
# `home-manager.users`.
#
# Every rendered scalar uses `lib.mkDefault` and every list uses
# `lib.mkBefore`, so higher-level modules (e.g. marchyo.users) writing to the
# same `users.users.<name>` override or extend without conflict.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  usersLib = import ./lib.nix { inherit lib; };

  # `lib.mkIf` does not gate option-path resolution: referencing
  # `home-manager.users` on a host without home-manager would fail even
  # under a false condition. `lib.optionalAttrs` omits the path entirely.
  homeManagerLoaded = builtins.hasAttr "home-manager" options;

  cfg = config.marchyo.identity;
  hostName = config.networking.hostName;

  enabled = usersLib.filterUsers {
    inherit cfg;
    platform = "nixos";
  };
  local = usersLib.filterUsers {
    inherit cfg;
    platform = "nixos";
    source = "local";
  };
  nonRootLocal = lib.filterAttrs (name: _: name != "root") local;
  rootLocal = local.root or null;

  resolveShell =
    u:
    if u.shell == null then
      null
    else if lib.isString u.shell then
      # Absolute paths pass through verbatim; other strings name a package.
      if lib.hasPrefix "/" u.shell then u.shell else pkgs.${u.shell}
    else
      u.shell;

  defaultHome = u: if u.home != null then u.home else "/home/${u.username}";

  effectiveGroups =
    name: u:
    let
      adminHere = u.sudo || lib.elem hostName u.adminOnHosts;
      # Group members may reference the identity by attribute name or login name.
      fromGroupSpec = lib.attrNames (
        lib.filterAttrs (_: g: lib.elem name g.members || lib.elem u.username g.members) cfg.groups
      );
    in
    lib.unique (u.groups ++ fromGroupSpec ++ lib.optional adminHere "wheel");

  renderLocalUser =
    name: u:
    lib.filterAttrs (_: v: v != null) {
      # nixpkgs already defines `name` at mkDefault priority (the attribute
      # name), so only define it — plainly — when the login name differs.
      name = if u.username == name then null else u.username;
      isNormalUser = lib.mkDefault (!u.isSystem);
      isSystemUser = lib.mkDefault u.isSystem;
      description = if u.fullName == "" then null else lib.mkDefault u.fullName;
      uid = if u.uid == null then null else lib.mkDefault u.uid;
      # nixpkgs' isNormalUser branch defines home/shell at mkDefault priority
      # itself; 900 beats those but still yields to any plain definition.
      home = lib.mkOverride 900 (defaultHome u);
      createHome = lib.mkDefault (!u.isSystem);
      shell = if resolveShell u == null then null else lib.mkOverride 900 (resolveShell u);
      extraGroups = lib.mkBefore (effectiveGroups name u);
      openssh.authorizedKeys.keys = lib.mkBefore u.sshAuthorizedKeys;
      openssh.authorizedKeys.keyFiles = lib.mkBefore u.sshAuthorizedKeyFiles;
      hashedPasswordFile =
        if u.hashedPasswordFile == null then null else lib.mkDefault u.hashedPasswordFile;
    };

  # Root already exists in the nixpkgs base configuration: only pass through
  # credentials and group membership, never identity-shaping fields like
  # isNormalUser/home/createHome.
  renderRoot =
    u:
    lib.filterAttrs (_: v: v != null) {
      openssh.authorizedKeys.keys = lib.mkBefore u.sshAuthorizedKeys;
      openssh.authorizedKeys.keyFiles = lib.mkBefore u.sshAuthorizedKeyFiles;
      hashedPasswordFile =
        if u.hashedPasswordFile == null then null else lib.mkDefault u.hashedPasswordFile;
      extraGroups = lib.mkBefore u.groups;
    };

  renderGroup =
    name: g:
    lib.filterAttrs (_: v: v != null) {
      gid = if g.gid == null then null else lib.mkDefault g.gid;
      members = lib.mkBefore (usersLib.groupMembersOf cfg name);
    };

  hmBindings = lib.filterAttrs (_: u: u.homeManager.enable && u.homeManager.import != null) enabled;
in
{
  options.marchyo.identity = usersLib.identityOptions;

  config = lib.mkMerge [
    {
      users.users = lib.mapAttrs renderLocalUser nonRootLocal;
      users.groups = lib.mapAttrs renderGroup cfg.groups;
      assertions = usersLib.mkAssertions cfg;
    }
    (lib.mkIf (rootLocal != null) {
      users.users.root = renderRoot rootLocal;
    })
    (lib.optionalAttrs homeManagerLoaded {
      home-manager.users = lib.mapAttrs (_: u: {
        imports = [ u.homeManager.import ];
      }) hmBindings;
    })
  ];
}
