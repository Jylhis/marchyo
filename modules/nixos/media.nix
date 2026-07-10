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

      # Players (local files; TUI music client comes from marchyo.defaults.musicPlayer)
      mpv
    ]
    # OBS Studio: full recording/streaming suite (gated on the media feature)
    ++ lib.optionals config.marchyo.media.enable [ obs-studio ]
    # Spotify GUI desktop app: always installed where it is available
    # (unfree, x86_64-linux only), alongside the TUI music default.
    ++
      lib.optionals
        (config.nixpkgs.config.allowUnfree && pkgs.stdenv.hostPlatform.system == "x86_64-linux")
        [
          spotify
        ];
}
