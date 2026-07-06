# Tests for the unified identity module (modules/users/nixos.nix).
# The module is part of nixosModules.default, so the helpers exercise it
# directly; scenarios cover rendering, group merging, admin sugar, root
# special-casing, platform/source filtering, HM bindings and coexistence
# with the higher-level marchyo.users module.
{ helpers, lib, ... }:
let
  inherit (helpers)
    testNixOSCheck
    testNixOSFails
    minimalConfig
    withTestUser
    ;
in
{
  # Scalar fields render with mkDefault semantics; lists are additive.
  eval-identity-basic =
    testNixOSCheck "identity-basic"
      (
        cfg:
        cfg.users.users.alice.isNormalUser
        && cfg.users.users.alice.createHome
        && cfg.users.users.alice.home == "/home/alice"
        && cfg.users.users.alice.description == "Alice Example"
        && cfg.users.users.alice.uid == 1500
        && cfg.users.users.alice.name == "alice"
        && lib.elem "video" cfg.users.users.alice.extraGroups
        && cfg.users.users.alice.openssh.authorizedKeys.keys == [ "ssh-ed25519 AAAAtest alice@test" ]
      )
      (
        minimalConfig
        // {
          marchyo.identity.users.alice = {
            fullName = "Alice Example";
            email = "alice@example.com";
            uid = 1500;
            groups = [ "video" ];
            sshAuthorizedKeys = [ "ssh-ed25519 AAAAtest alice@test" ];
          };
        }
      );

  # sudo grants wheel everywhere; adminOnHosts only on matching hostnames.
  eval-identity-admin-sugar =
    testNixOSCheck "identity-admin-sugar"
      (
        cfg:
        lib.elem "wheel" cfg.users.users.sudoer.extraGroups
        && lib.elem "wheel" cfg.users.users.hostadmin.extraGroups
        && !(lib.elem "wheel" cfg.users.users.elsewhere.extraGroups)
      )
      (
        minimalConfig
        // {
          networking.hostName = "adminhost";
          marchyo.identity.users = {
            sudoer.sudo = true;
            hostadmin.adminOnHosts = [ "adminhost" ];
            elsewhere.adminOnHosts = [ "otherhost" ];
          };
        }
      );

  # Per-user `groups` and per-group `members` merge both ways: into
  # users.groups.<g>.members and into each member's extraGroups.
  eval-identity-group-merge =
    testNixOSCheck "identity-group-merge"
      (
        cfg:
        lib.elem "alice" cfg.users.groups.media.members
        && lib.elem "bob" cfg.users.groups.media.members
        && cfg.users.groups.media.gid == 2500
        && lib.elem "media" cfg.users.users.alice.extraGroups
        && lib.elem "media" cfg.users.users.bob.extraGroups
      )
      (
        minimalConfig
        // {
          marchyo.identity = {
            users = {
              alice = { };
              bob.groups = [ "media" ];
            };
            groups.media = {
              gid = 2500;
              members = [ "alice" ];
            };
          };
        }
      );

  # System users render as isSystemUser without a home directory being created.
  eval-identity-system-user =
    testNixOSCheck "identity-system-user"
      (
        cfg:
        cfg.users.users.buildbot.isSystemUser
        && !cfg.users.users.buildbot.isNormalUser
        && !cfg.users.users.buildbot.createHome
      )
      (
        minimalConfig
        // {
          marchyo.identity.users.buildbot = {
            isSystem = true;
            platforms = [ "nixos" ];
          };
          # Primary-group rendering for system users is host config's job.
          users.users.buildbot.group = "buildbot";
          users.groups.buildbot = { };
        }
      );

  # Users restricted to darwin (or disabled) never reach NixOS users.users.
  eval-identity-filters =
    testNixOSCheck "identity-filters"
      (cfg: !(cfg.users.users ? maconly) && !(cfg.users.users ? retired))
      (
        minimalConfig
        // {
          marchyo.identity.users = {
            maconly.platforms = [ "darwin" ];
            retired.enable = false;
          };
        }
      );

  # Shell strings resolve via pkgs.<shell>; username decouples the login
  # name from the attribute name.
  eval-identity-shell-username =
    testNixOSCheck "identity-shell-username"
      (cfg: cfg.users.users.worker.name == "svc-worker" && cfg.users.users.worker.shell.pname == "fish")
      (
        minimalConfig
        // {
          marchyo.identity.users.worker = {
            username = "svc-worker";
            shell = "fish";
          };
          programs.fish.enable = true;
        }
      );

  # Root is passthrough-only: keys and groups land, identity-shaping fields
  # (isNormalUser, home, createHome) stay untouched.
  eval-identity-root-passthrough =
    testNixOSCheck "identity-root-passthrough"
      (
        cfg:
        lib.elem "ssh-ed25519 AAAAroot root@test" cfg.users.users.root.openssh.authorizedKeys.keys
        && cfg.users.users.root.home == "/root"
        && !cfg.users.users.root.isNormalUser
      )
      (
        minimalConfig
        // {
          marchyo.identity.users.root = {
            sshAuthorizedKeys = [ "ssh-ed25519 AAAAroot root@test" ];
          };
        }
      );

  fail-identity-root-system =
    testNixOSFails "identity-root-system" "cannot be declared a system user"
      (
        minimalConfig
        // {
          marchyo.identity.users.root.isSystem = true;
        }
      );

  # Phase 1: directory backends are schema-only and must fail loudly.
  fail-identity-nonlocal-source =
    testNixOSFails "identity-nonlocal-source" "directory backends are not implemented yet"
      (
        minimalConfig
        // {
          marchyo.identity.users.corp.source = "ldap";
        }
      );

  # homeManager.enable + import renders a home-manager.users binding.
  eval-identity-hm-binding =
    testNixOSCheck "identity-hm-binding" (cfg: cfg.home-manager.users ? hmuser)
      (
        minimalConfig
        // {
          marchyo.identity.users.hmuser = {
            homeManager = {
              enable = true;
              import = ../fixtures/hm-empty.nix;
            };
          };
          home-manager.users.hmuser.home.stateVersion = "25.11";
        }
      );

  # Coexistence: marchyo.users writes the same users.users entry at normal
  # priority and must win over the identity module's mkDefault values.
  eval-identity-marchyo-coexistence =
    testNixOSCheck "identity-marchyo-coexistence"
      (
        cfg:
        cfg.users.users.testuser.description == "Test User"
        && lib.elem "wheel" cfg.users.users.testuser.extraGroups
        && lib.elem "video" cfg.users.users.testuser.extraGroups
      )
      (withTestUser {
        marchyo.identity.users.testuser = {
          # Loses to marchyo.users' plain-priority "Test User" description.
          fullName = "Identity Name";
          groups = [ "video" ];
        };
      });
}
