{ lib, config, ... }:
{
  # Only configure when dropbox is enabled
  config = lib.mkIf config.services.dropbox.enable {
    services.dropbox = {
      path = lib.mkDefault "${config.home.homeDirectory}/Dropbox";
    };
  };
}
