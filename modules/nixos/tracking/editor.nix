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
  };
}
