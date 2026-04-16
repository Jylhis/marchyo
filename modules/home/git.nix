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
      settings = {
        user = {
          name = userConfig.fullname;
          inherit (userConfig) email;
        };
        init.defaultBranch = lib.mkDefault "main";
        core = {
          untrackedcache = lib.mkDefault true;
          fsmonitor = lib.mkDefault false;
        };
        merge = {
          conflictStyle = lib.mkDefault "zdiff3";
        };
        rebase = {
          updateRefs = lib.mkDefault true;
          autoSquash = lib.mkDefault true;
          autoStash = lib.mkDefault true;
        };
        color = {
          ui = lib.mkDefault true;
        };
        column = {
          ui = lib.mkDefault "auto";
        };
        fetch = {
          writeCommitGraph = lib.mkDefault true;
          prune = lib.mkDefault true;
          pruneTags = lib.mkDefault true;
          all = lib.mkDefault true;
        };
        branch = {
          sort = lib.mkDefault "-committerdate";
        };
        pull.rebase = lib.mkDefault true;
        diff = {
          algorithm = lib.mkDefault "histogram";
          mnemonicPrefix = lib.mkDefault true;
          renames = lib.mkDefault true;
          colorMoved = lib.mkDefault "plain";
          colorMovedWS = lib.mkDefault "ignore-space-at-eol";
        };
        push = {
          autoSetupRemote = lib.mkDefault true;
        };
        help = {
          autocorrect = lib.mkDefault "prompt";
        };
        rerere = {
          enabled = lib.mkDefault true;
          autoupdate = lib.mkDefault true;
        };
        tag = {
          sort = lib.mkDefault "version:refname";
        };
      };
      ignores = [
        # Linux
        "*~"
        ".fuse_hidden*"
        ".directory"
        ".Trash-*"
        ".nfs*"
        "nohup.out"

        # macOS
        ".DS_Store"
        ".AppleDouble"
        ".LSOverride"

        # Windows
        "Thumbs.db"
        "ehthumbs.db"
        "Desktop.ini"

        # Editor swap/backup files
        "*.swp"
        "*.swo"
      ];
    };
  };
}
