{ options, ... }:
{
  config =
    if (options ? fonts && options.fonts ? fontconfig) then
      {
        fonts.fontconfig = {
          enable = true;
          # Mirrors the Jylhis Design System v2 type roles (see
          # modules/generic/stylix.nix): Zilla Slab display, Hanken Grotesk
          # body, IBM Plex Mono (Nerd Font patch) mono.
          defaultFonts = {
            serif = [ "Zilla Slab" ];
            sansSerif = [ "Hanken Grotesk" ];
            monospace = [ "BlexMono Nerd Font" ];
          };
        };
      }
    else
      { };
}
