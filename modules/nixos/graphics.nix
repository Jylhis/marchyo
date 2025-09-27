{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    pinta # basic image editing tool
  ];
  # GPU optimizations
  hardware.graphics = {
    enable = true;
    enable32Bit = true;

    # Intel specific
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vaapiVdpau
      intel-compute-runtime
    ];
  };
}
