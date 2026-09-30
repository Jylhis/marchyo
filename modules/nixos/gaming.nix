# Desktop + opt-in gaming bundle. Gated on both marchyo.desktop.enable and
# marchyo.gaming.enable so a plain desktop carries none of this weight.
#
# Steam sets hardware.graphics.enable32Bit itself; the desktop already enables
# 32-bit graphics on x86 (modules/nixos/desktop-config.nix), so no extra wiring.
# That unconditional enable32Bit is also why the bundle is gated on x86_64:
# nixpkgs asserts against 32-bit graphics on other architectures, and Steam
# has no non-x86 build anyway.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  isX86 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.gaming.enable && isX86) {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = lib.mkDefault true;
    };

    programs.gamemode.enable = lib.mkDefault true;
    # Normal priority (not mkDefault) so it wins over the mkDefault=false that
    # programs.steam sets when its gamescope session is off; still overridable.
    programs.gamescope.enable = true;

    hardware.steam-hardware.enable = lib.mkDefault true;
    hardware.xpadneo.enable = lib.mkDefault true;

    environment.systemPackages = with pkgs; [
      lutris
      heroic
      mangohud
      protonup-qt
    ];
  };
}
