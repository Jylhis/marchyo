{ config, lib, ... }:
{
  # 1Password CLI is useful headless (shell plugins, `op`); keep it unconditional.
  programs._1password.enable = true;

  # The 1Password GUI is a desktop app — only install it with the desktop stack.
  programs._1password-gui = lib.mkIf config.marchyo.desktop.enable {
    enable = true;
    polkitPolicyOwners = lib.attrNames (
      lib.filterAttrs (_name: user: user.enable) config.marchyo.users
    );
  };
}
