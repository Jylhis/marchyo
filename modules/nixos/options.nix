{ lib, ... }:
let
  inherit (lib) mkOption types;
  # cfg = config.marchyo;

  userOpts =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = ''
            If set to false, the user account will have any Marchyo stuff.
          '';
        };
        name = mkOption {
          type = types.str;
          default = name;
          description = ''
                        The name of the user account.
            	    use `users.users.{name}.name`
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
  # TODO:
  # user
  # timezone
  options.marchyo = {
    users = mkOption {
      default = { };
      type = with types; attrsOf (submodule userOpts);
      # example = {
      #   alice = {
      #     # uid = 1234;
      #     # description = "Alice Q. User";
      #     # home = "/home/alice";
      #     # createHome = true;
      #     # group = "users";
      #     # extraGroups = [ "wheel" ];
      #     # shell = "/bin/sh";
      #   };
      # };
      # description = ''
      #   Additional user accounts to be created automatically by the system.
      #   This can also be used to set options for root.
      # '';
    };
  };
}
