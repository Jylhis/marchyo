# Desktop + opt-in gaming bundle. Gated on both marchyo.desktop.enable and
# marchyo.gaming.enable so a plain desktop carries none of this weight.
#
# Steam sets hardware.graphics.enable32Bit itself; the desktop already enables
# 32-bit graphics on x86 (modules/nixos/desktop-config.nix), so no extra wiring.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.gaming.enable) {
    programs.steam = {
      enable = true;
      # Remote Play streaming ports on the LAN.
      remotePlay.openFirewall = lib.mkDefault true;
    };

    # Optimises CPU governor / scheduling while a game runs (opt-in per game).
    programs.gamemode.enable = lib.mkDefault true;
    # Gamescope micro-compositor (cap_sys_nice wrapper) for upscaling/frame limits.
    programs.gamescope.enable = lib.mkDefault true;

    # Controller/VR/Steam-Deck udev rules, and the Xbox controller driver.
    hardware.steam-hardware.enable = lib.mkDefault true;
    hardware.xpadneo.enable = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      lutris # Wine/Proton game launcher
      heroic # Epic / GOG / Amazon launcher
      mangohud # in-game performance overlay
      protonup-qt # manage GE-Proton / Wine-GE versions
    ];
  };
}
