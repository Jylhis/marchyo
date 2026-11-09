{ options, pkgs, ... }:
let
  # Family names come from the design tokens (lib/design/nix/fonts.nix).
  fonts = import "${pkgs.jylhis-design-src}/nix/fonts.nix";
in
{
  config =
    if (options ? fonts && options.fonts ? fontconfig) then
      {
        fonts.fontconfig = {
          enable = true;
          defaultFonts = {
            serif = [ "DejaVu Serif" ];
            sansSerif = [ fonts.body ];
            monospace = [ fonts.mono ];
          };
        };
      }
    else
      { };
}
