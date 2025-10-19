{
  osConfig ? { },
  config,
  lib,
  ...
}:
let
  # Only access user config if running within NixOS
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  userConfig = if hasOsConfig then osConfig.marchyo.users."${config.home.username}" or null else null;
  isEnabled = userConfig != null && userConfig.enable or false;
in
{
  programs = lib.mkIf isEnabled {
    git = {
      enable = true;
      userName = userConfig.fullname;
      userEmail = userConfig.email;
      extraConfig = {
        init.defaultBranch = lib.mkDefault "main";
        core = {
          untrackedcache = lib.mkDefault true;
          fsmonitor = lib.mkDefault true;
        };
        merge = {
          conflictStyle = lib.mkDefault "zdiff3";
        };
        rebase = {
          updateRefs = lib.mkDefault true;
        };
        color = {
          ui = lib.mkDefault true;
        };
        column = {
          ui = lib.mkDefault "auto";
        };
        fetch = {
          writeCommitGraph = lib.mkDefault true;
        };
        branch = {
          sort = lib.mkDefault "-committerdate";
        };
        pull.rebase = lib.mkDefault true;
        diff = {
          colorMoved = lib.mkDefault "zebra";
          colorMovedWS = lib.mkDefault "ignore-space-at-eol";
        };
        rerere = {
          enabled = lib.mkDefault true;
        };
      };
    };
  };
}
