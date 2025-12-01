{
  pkgs,
  lib,
  config,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    [
      # File format support
      libheif
      libheif.out

      # Players
      mpv
    ]
    ++ (lib.optionals config.nixpkgs.config.allowUnfree (
      lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [
        pkgs.spotify
      ]
    ));

}
