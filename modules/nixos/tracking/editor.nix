# Editor tracking: self-hosted wakapi + wakatime-cli.
#
# wakapi runs bound to 127.0.0.1 and stores heartbeats in SQLite. After the
# first start you must log in at http://127.0.0.1:<port>, generate an API
# key, and place it in ~/.wakatime.cfg.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  editorCfg = cfg.editor;
  d = config.marchyo.defaults;
in
{
  config = lib.mkIf (cfg.enable && editorCfg.enable) {
    environment.systemPackages = with pkgs; [
      wakatime-cli
      wakapi
    ];

    services.wakapi = {
      enable = true;
      settings = {
        server = {
          listen_ipv4 = "127.0.0.1";
          inherit (editorCfg) port;
        };
        db.dialect = "sqlite3";
      };
    };

    marchyo.tracking.editor.plugins = {
      brave.enable = lib.mkDefault (d.browser == "brave");
      chrome.enable = lib.mkDefault (d.browser == "google-chrome");
      chromium.enable = lib.mkDefault (
        d.browser == "chromium" || config.programs.chromium.enable or false
      );
      firefox.enable = lib.mkDefault (
        d.browser == "firefox" || config.programs.firefox.enable or false
      );
      emacs.enable = lib.mkDefault (
        d.editor == "emacs"
        || d.terminalEditor == "emacs"
        || config.services.emacs.enable or false
        || config.programs.emacs.enable or false
      );
      vscode.enable = lib.mkDefault (d.editor == "vscode");
      vscodium.enable = lib.mkDefault (d.editor == "vscodium");
      neovim.enable = lib.mkDefault (
        d.terminalEditor == "neovim" || config.programs.neovim.enable or false
      );
      vim.enable = lib.mkDefault (config.programs.vim.enable or false);
      helix.enable = lib.mkDefault (
        d.terminalEditor == "helix" || config.programs.helix.enable or false
      );
      zed.enable = lib.mkDefault (d.editor == "zed");
    };
  };
}
