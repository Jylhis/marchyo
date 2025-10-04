{ config, ... }:
{
  programs = {
    # Enable 1Password CLI for shell plugins and op command
    _1password.enable = true;

    _1password-gui = {
      enable = true;
      polkitPolicyOwners =
        let
          mUsers = builtins.attrNames config.marchyo.users;
        in
        mUsers;
    };
  };
}
