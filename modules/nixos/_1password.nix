{ config, lib, ... }:
let
  mUsers = builtins.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
in
{
  programs = {
    # Enable 1Password CLI for shell plugins and op command
    _1password.enable = true;

    _1password-gui = {
      enable = true;
      polkitPolicyOwners = mUsers;
    };
  };

  # The 1Password-BrowserSupport wrapper is setgid `onepassword`; it verifies
  # the calling browser by reading its /proc/<pid>/exe, which requires the
  # invoking user to be in the `onepassword` group. Without this the desktop
  # app rejects the browser extension's native-messaging connection with
  # "Failed to verify browser permissions" (PermissionDenied).
  users.users = lib.genAttrs mUsers (_name: {
    extraGroups = [ "onepassword" ];
  });
}
