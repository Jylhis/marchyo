{ lib, ... }:
let
  inherit (lib) mkOption types;

  userOpts =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = ''
            If set to false, the user account will not have any Marchyo stuff.
          '';
        };

        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The name of the user account.
            Use `users.users.{name}.name` to reference it.
          '';
        };
        fullname = mkOption {
          type = types.str;
          description = "Your full name";
        };
        email = mkOption {
          type = types.str;
          description = "Your email address";
        };

        uid = mkOption {
          type = types.nullOr types.int;
          default = null;
          example = 501;
          description = ''
            Numeric user id. On NixOS this sets `users.users.<name>.uid`.
            On nix-darwin, providing the uid opts the user into
            `users.knownUsers` so marchyo can manage the login shell (bash)
            declaratively. It must match the account's existing uid (the first
            macOS user is 501) — a mismatch aborts nix-darwin activation.
            When unset, the login shell on macOS is left unmanaged; bash is
            still registered in /etc/shells for a manual `chsh`.
          '';
        };
      };
    };
in
{
  options.marchyo.users = mkOption {
    default = { };
    type = with types; attrsOf (submodule userOpts);
    description = ''
      Marchyo user configuration.
      Defines users with associated metadata like fullname and email.
    '';
  };
}
