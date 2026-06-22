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
        conflict-marker-style = lib.mkDefault "diff";
      };
      git = {
        auto-local-bookmark = lib.mkDefault true;
      };
      aliases = lib.mkDefault {
        l = [ "log" ];
        # Advance the closest bookmark to the parent of the working copy —
        # the standard jj "push my branch forward" idiom.
        tug = [
          "bookmark"
          "move"
          "--from"
          "closest_bookmark(@-)"
          "--to"
          "@-"
        ];
      };
      revset-aliases = lib.mkDefault {
        "closest_bookmark(to)" = "heads(::to & bookmarks())";
      };
    };
  };
}
