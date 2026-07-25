{ pkgs, ... }:
{
  # Fonts
  imports = [
    ../generic/fontconfig.nix
  ];
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      # Programming fonts (Nerd Font variants only). BlexMono is the Nerd Font
      # patch of IBM Plex Mono — the Jylhis Design System v2 mono role, and the
      # face marchyo's desktop chrome asks for by name.
      nerd-fonts.blex-mono
      nerd-fonts.caskaydia-mono
      nerd-fonts.jetbrains-mono # v2 mono fallback

      # UI and reading fonts — v2 display/body roles plus their fallbacks
      zilla-slab # display / headings
      hanken-grotesk # body
      ibm-plex # unpatched IBM Plex Mono (documents, PDF export)
      inter # v2 body fallback
      liberation_ttf

    ];
    fontconfig = {
      cache32Bit = true;

      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
        autohint = false;
      };

      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };
}
