# Desktop-only: 1Password's GUI application and its browser-integration group.
{ config, lib, ... }:
let
  cfg = config.marchyo;
  mUsers = builtins.attrNames (lib.filterAttrs (_name: user: user.enable) config.marchyo.users);
in
{
  config = lib.mkIf cfg.desktop.enable {
    programs = {
      _1password.enable = lib.mkDefault true;

      _1password-gui = {
        enable = lib.mkDefault true;
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
  };
}
