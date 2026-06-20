# Jujutsu (jj) config, wired to the marchyo user model the same way git is
# (modules/home/git.nix): identity comes from marchyo.users.<username>, so a
# consumer that sets `marchyo.users.<name>` gets a configured jj without
# repeating name/email. Cross-platform (no Linux-only assumptions).
{
  osConfig ? { },
  config,
  lib,
  ...
}:
let
  marchyoUsers = (osConfig.marchyo or { }).users or { };
  hasUser = builtins.hasAttr config.home.username marchyoUsers;
  userConfig =
    if hasUser then
      marchyoUsers.${config.home.username}
    else
      {
        enable = false;
        fullname = "";
        email = "";
      };
in
{
  programs.jujutsu = lib.mkIf userConfig.enable {
    enable = lib.mkDefault true;
    settings = {
      user = {
        name = userConfig.fullname;
        inherit (userConfig) email;
      };
      ui = {
        default-command = lib.mkDefault "log";
        diff-formatter = lib.mkDefault ":git";
      };
      git = {
        auto-local-bookmark = lib.mkDefault true;
      };
    };
  };
}
