{ pkgs, ... }:
{
  services = {
    earlyoom.enable = true;
  };
  programs = {
    nix-ld.enable = true;
  };

  environment.systemPackages = with pkgs; [
    sysz # systemctl tui
    lazyjournal # journald and logs
    fastfetch # shows system information
    btop # beautiful resource manager
  ];
}
