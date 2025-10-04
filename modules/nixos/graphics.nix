{
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    pinta # basic image editing tool
  ];
  # GPU optimizations
  hardware.graphics = {
    enable = lib.mkDefault true;
    enable32Bit = lib.mkDefault (pkgs.stdenv.hostPlatform.system == "x86_64-linux");

    # Intel specific packages - only on x86_64
    extraPackages = lib.mkDefault (
      lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
        with pkgs;
        [
          intel-media-driver
          intel-vaapi-driver
          vaapiVdpau
          intel-compute-runtime
        ]
      )
    );
  };
}
