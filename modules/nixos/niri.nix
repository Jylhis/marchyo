{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo;
  hasNvidia = builtins.elem "nvidia" (config.marchyo.graphics.vendors or [ ]);
in
{
  config = lib.mkIf cfg.desktop.enable {
    programs.niri.enable = true;

    # NVIDIA-specific settings
    environment.sessionVariables = lib.mkIf hasNvidia {
      # Help niri find the right GPU (dGPU typically card1, iGPU card0)
      WLR_DRM_DEVICES = lib.mkDefault "/dev/dri/card1:/dev/dri/card0";
    };
  };
}
