{ pkgs, ... }:
{
  documentation = {
    enable = true;
    doc.enable = true;
    dev.enable = true;
    info.enable = true;
    man.enable = true;
    nixos = {
      enable = true;
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
