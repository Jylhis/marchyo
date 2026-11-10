{ lib, ... }:
let
  inherit (lib) mkOption types;

  userOpts = {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = ''
          If set to false, the user account will not have any Marchyo stuff.
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
