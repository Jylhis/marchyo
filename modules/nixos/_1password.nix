{ config, ... }:
{
  programs = {
    _1password.enable = true;
    _1password-gui = {
      enable = true;
      # TODO: shell plugins
      polkitPolicyOwners =
        let
          mUsers = builtins.attrNames config.marchyo.users;
        in
        mUsers;
    };
  };
}
