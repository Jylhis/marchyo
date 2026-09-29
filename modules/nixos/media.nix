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
      libheif
      # mpv for local files; the TUI music client comes from marchyo.defaults.musicPlayer.
      mpv
    ]
    ++ lib.optionals config.marchyo.media.enable [ obs-studio ]
    ++
      lib.optionals
        (config.nixpkgs.config.allowUnfree && pkgs.stdenv.hostPlatform.system == "x86_64-linux")
        [
          spotify
        ];
}
