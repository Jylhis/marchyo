{
  osConfig,
  config,
  lib,
  ...
}:
let
  userConfig = osConfig.marchyo.users."${config.home.username}";
in
{
  programs = lib.mkIf userConfig.enable {
    git = {
      enable = true;
      lfs.enable = lib.mkDefault true;
      ignores = lib.mkDefault [
        "*~"
        # Emacs
        "\#*\#"
        "*.elc"
        ".\#*"
        # Org-mode
        ".org-id-locations"
        "*_archive"
        # Intellij
        "*.iml"
        "*.ipr"
        "*.iws"
        ".idea/"
        # VIM
        ".*.s[a-w][a-z]"
        "*.un~"
        "Session.vim"
        ".netrwhist"
      ];
      settings = {
        user = {
          name = userConfig.fullname;
          inherit (userConfig) email;
        };
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
        push = {
          autoSetupRemote = lib.mkDefault true;
        };
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
