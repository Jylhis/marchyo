{ lib, ... }:
{
  # Compressed RAM-backed swap. Cheap way to extend effective memory and reduce
  # disk swapping; mkDefault so a host can disable or resize it.
  zramSwap = {
    enable = lib.mkDefault true;
    algorithm = lib.mkDefault "zstd";
    memoryPercent = lib.mkDefault 50;
  };
}
