{ pkgs, lib, ... }:
{
  documentation = {
    enable = lib.mkDefault true;
    doc.enable = lib.mkDefault true;
    dev.enable = lib.mkDefault true;
    info.enable = lib.mkDefault true;
    man.enable = lib.mkDefault true;
    nixos = {
      enable = lib.mkDefault true;
      # extraModuleSources # TODO
    };
  };
  environment.systemPackages = with pkgs; [
    man-pages
    man-pages-posix
    linux-doc
    clang-manpages
    zeal
    stdmanpages
  ];
}
