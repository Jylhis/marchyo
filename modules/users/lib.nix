# Unified user/group identity contract shared by the platform renderers
# (./nixos.nix and ./darwin.nix). The whole cross-platform contract lives in
# this one file: option types, the option declaration for the
# `marchyo.identity` namespace, filtering helpers, and shared assertions.
# The directory is self-contained and relocatable — renderers only import
# their sibling ./lib.nix.
{ lib }:
let
  inherit (lib) mkOption types;

  userSubmodule =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Whether this identity is rendered on this host. Human identities
            should keep the default (propagate everywhere); host-specific
            system accounts should declare `enable = lib.mkDefault false`
            and let individual hosts opt in.
          '';
        };

        username = mkOption {
          type = types.str;
          default = name;
          description = "Login name. Defaults to the attribute name.";
        };

        fullName = mkOption {
          type = types.str;
          default = "";
          description = "Full name, rendered as the GECOS description.";
        };

        email = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Email address, for other modules to read.";
        };

        uid = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Stable UID when set; otherwise allocated by the OS.";
        };

        source = mkOption {
          type = types.enum [
            "local"
            "ldap"
            "kanidm"
            "entra"
          ];
          default = "local";
          description = ''
            Identity backend. Only "local" is implemented (Phase 1); the
            directory backends are reserved for future phases and currently
            fail evaluation with an assertion.
          '';
        };

        isSystem = mkOption {
          type = types.bool;
          default = false;
          description = "Render as a system user (`isSystemUser`) instead of a normal user.";
        };

        shell = mkOption {
          type = types.nullOr (types.either types.str types.package);
          default = null;
          description = ''
            Login shell. A package is used as-is; a string is resolved via
            `pkgs.<shell>` unless it is an absolute path (starts with `/`),
            which is passed through verbatim. `null` leaves the platform
            default untouched.
          '';
        };

        home = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Home directory. `null` derives it per platform:
            `/home/<username>` on NixOS, `/Users/<username>` on darwin.
          '';
        };

        homeManager = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = "Render a `home-manager.users.<name>` binding for this identity.";
          };

          import = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Home Manager module imported into the per-user binding.";
          };
        };

        sshAuthorizedKeys = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Inline SSH public keys.";
        };

        sshAuthorizedKeyFiles = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = "Files containing SSH public keys (e.g. sops-managed paths). NixOS only.";
        };

        hashedPasswordFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Runtime path to a hashed password file. NixOS only.";
        };

        groups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Supplementary groups for this user. Additive with
            `marchyo.identity.groups.<group>.members`.
          '';
        };

        sudo = mkOption {
          type = types.bool;
          default = false;
          description = "Grant admin rights everywhere (wheel on NixOS, admin group on darwin).";
        };

        adminOnHosts = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Grant admin rights only on hosts whose `networking.hostName` is listed.";
        };

        platforms = mkOption {
          type = types.listOf (
            types.enum [
              "nixos"
              "darwin"
            ]
          );
          default = [
            "nixos"
            "darwin"
          ];
          description = "Platforms this identity is rendered on.";
        };
      };
    };

  groupSubmodule = {
    options = {
      gid = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Stable GID when set.";
      };

      members = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Group members. Additive with per-user
          `marchyo.identity.users.<user>.groups`.
        '';
      };
    };
  };

  # Option declaration shared verbatim by both renderers, so the schema
  # cannot drift between platforms.
  identityOptions = {
    users = mkOption {
      type = types.attrsOf (types.submodule userSubmodule);
      default = { };
      description = "Unified user identities, rendered to the platform user database.";
    };

    groups = mkOption {
      type = types.attrsOf (types.submodule groupSubmodule);
      default = { };
      description = "Unified group definitions, rendered to the platform group database.";
    };
  };

  # Enabled users targeted at `platform`, optionally restricted to one
  # identity source.
  filterUsers =
    {
      cfg,
      platform,
      source ? null,
    }:
    lib.filterAttrs (
      _name: u: u.enable && lib.elem platform u.platforms && (source == null || u.source == source)
    ) cfg.users;

  # All members of a group, as login names: explicit `groups.<name>.members`
  # merged with every enabled user listing the group in its per-user
  # `groups`. Member entries may be identity attribute names (translated to
  # the identity's `username`) or literal login names of users not managed
  # by this module (kept as-is).
  groupMembersOf =
    cfg: groupName:
    let
      toUsername = m: (cfg.users.${m} or { username = m; }).username;
      fromGroup = map toUsername (cfg.groups.${groupName} or { members = [ ]; }).members;
      fromUsers = lib.mapAttrsToList (_name: u: u.username) (
        lib.filterAttrs (_name: u: u.enable && lib.elem groupName u.groups) cfg.users
      );
    in
    lib.unique (fromGroup ++ fromUsers);

  # Cross-platform assertions: Phase-1 source restriction + root special
  # cases. `cfg` is the `marchyo.identity` config value.
  mkAssertions =
    cfg:
    let
      enabledUsers = lib.filterAttrs (_name: u: u.enable) cfg.users;
      nonLocal = lib.filterAttrs (_name: u: u.source != "local") enabledUsers;
      root = cfg.users.root or null;
    in
    [
      {
        assertion = nonLocal == { };
        message = ''
          marchyo.identity: directory backends are not implemented yet — Phase 1 supports source = "local" only.
          Offending user(s): ${lib.concatStringsSep ", " (lib.attrNames nonLocal)}.
          Set source = "local" (or disable the user) until LDAP/Kanidm/Entra support lands.
        '';
      }
    ]
    ++ lib.mapAttrsToList (name: _: {
      assertion = false;
      message = "marchyo.identity.users.${name}: homeManager.enable = true requires homeManager.import to be set — an empty Home Manager binding would fail evaluation (no home.stateVersion). Set homeManager.import, or disable the binding and manage home-manager.users.${name} directly.";
    }) (lib.filterAttrs (_name: u: u.homeManager.enable && u.homeManager.import == null) enabledUsers)
    ++ lib.optionals (root != null) [
      {
        assertion = !root.isSystem;
        message = "marchyo.identity.users.root: root already exists as a base account and cannot be declared a system user (isSystem must be false).";
      }
      {
        assertion = !root.homeManager.enable;
        message = "marchyo.identity.users.root: Home Manager bindings for root are not supported (homeManager.enable must be false).";
      }
    ];
in
{
  inherit
    userSubmodule
    groupSubmodule
    identityOptions
    filterUsers
    groupMembersOf
    mkAssertions
    ;
}
